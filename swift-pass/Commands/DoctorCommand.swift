import ArgumentParser
import Foundation
import Noora

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check that swift-pass is configured correctly.",
        discussion: "Runs a series of checks to verify the CLI is working and the environment is ready."
    )

    func run() async throws {
        let vault = SecretVault()
        let store = ValetSecretStore()
        let catalogStore = KeychainGroupCatalogStore()
        let expectedServiceName = store.configuration.serviceName
        let metadataServiceName = catalogStore.configuration.serviceName
        let signingStatus = try? CurrentProcessSigningInspector().inspect()
        let hasExpectedSigning = signingStatus?.hasExpectedKeychainEntitlements(for: expectedServiceName) ?? false

        if signingStatus == nil {
            Noora().warning(
                .alert(
                    "Could not inspect signing information",
                    takeaway: "Run the Xcode-generated binary directly if you want doctor to confirm the signed application identifier."
                ),
                .alert(
                    "Keychain access still needs to be verified",
                    takeaway: "Rerun \(.command("doctor")) from a built executable after signing is configured."
                )
            )

            return
        }

        guard hasExpectedSigning else {
            Noora().warning(
                .alert(
                    "Current executable is not signed for the expected identifier",
                    takeaway: "The running binary at '\(signingStatus?.executablePath ?? CommandLine.arguments[0])' does not embed the expected '\(expectedServiceName)' application identifier."
                ),
                .alert(
                    "Run the signed Xcode build",
                    takeaway: "Build with `xcodebuild -project \"swift-pass.xcodeproj\" -scheme \"swift-pass\" -configuration Debug -derivedDataPath Build build` and rerun the built executable from `Build/Products/Debug/swift-pass`."
                )
            )

            return
        }

        guard vault.canAccessSecretStore() else {
            Noora().warning(
                .alert(
                    "Keychain access is not available",
                    takeaway: "Valet is configured with the '\(expectedServiceName)' service identifier."
                ),
                .alert(
                    "Current environment cannot open the Keychain",
                    takeaway: "This can happen in a restricted or non-interactive session even when the binary is signed correctly."
                ),
                .alert(
                    "Verify from your normal login session",
                    takeaway: "Rerun \(.command("doctor")) from Xcode or Terminal while signed into your macOS desktop session."
                )
            )

            return
        }

        guard vault.canAccessCatalogStore() else {
            Noora().warning(
                .alert(
                    "Metadata Keychain access is not available",
                    takeaway: "swift-pass uses '\(metadataServiceName)' to store group and default-group metadata."
                ),
                .alert(
                    "Current environment cannot open the metadata Keychain store",
                    takeaway: "Try rerunning \(.command("doctor")) from your normal signed desktop session."
                )
            )

            return
        }

        let catalogStatus: TerminalText

        do {
            let status = try vault.doctorStatus()
            let alerts = warningAlerts(for: status)

            if !alerts.isEmpty {
                Noora().warning(alerts)

                return
            }

            guard let catalog = status.catalog else {
                throw GroupCatalogError.defaultGroupNotConfigured
            }
            catalogStatus = "The group catalog is readable and the default group is '\(catalog.defaultGroup)'."
        } catch {
            Noora().warning(
                .alert(
                    "swift-pass could not complete the storage audit",
                    takeaway: TerminalText(stringLiteral: error.localizedDescription)
                ),
                .alert(
                    "Keychain access is available",
                    takeaway: "The Keychain services are reachable, but swift-pass could not verify group metadata and secret parentage."
                )
            )

            return
        }

        Noora().success(
            .alert(
                "Keychain setup looks good",
                takeaways: [
                    "swift-argument-parser is set up and parsing commands correctly.",
                    "Noora is available for interactive terminal output.",
                    "The running executable is signed with the expected application identifier for '\(expectedServiceName)'.",
                    "Valet can access the Keychain with the '\(expectedServiceName)' service identifier.",
                    "swift-pass can access the metadata Keychain store '\(metadataServiceName)'.",
                    catalogStatus,
                    "All stored secrets belong to a configured group.",
                ]
            )
        )
    }

    private func warningAlerts(for status: DoctorStatus) -> [WarningAlert] {
        var alerts: [WarningAlert] = []

        if status.catalog == nil {
            alerts.append(
                WarningAlert.alert(
                    "No default group is configured.",
                    takeaway: "Run \(TerminalText.Component.command("swift-pass create default")) to initialize the group catalog."
                )
            )
        }

        let orphanedReferences = status.orphanedSecretReferences

        if !orphanedReferences.isEmpty {
            alerts.append(
                WarningAlert.alert(
                    "Found \(orphanedReferences.count) scoped secret\(orphanedReferences.count == 1 ? "" : "s") without a parent group: \(formattedSecretPaths(orphanedReferences.map(\.displayPath))).",
                    takeaway: "Create the missing group or subgroup before relying on those secrets."
                )
            )
        }

        if !status.legacySecretEntries.isEmpty {
            alerts.append(
                WarningAlert.alert(
                    "Found \(status.legacySecretEntries.count) legacy secret\(status.legacySecretEntries.count == 1 ? "" : "s") without group metadata: \(formattedSecretPaths(status.legacySecretEntries.map(\.name))).",
                    takeaway: "Run \(TerminalText.Component.command("swift-pass create default")) or store a new secret to migrate legacy entries into the default group."
                )
            )
        }

        return alerts
    }

    private func formattedSecretPaths(_ paths: [String], limit: Int = 5) -> TerminalText {
        let sortedPaths = paths.sorted()
        let preview = sortedPaths.prefix(limit).joined(separator: ", ")

        if sortedPaths.count > limit {
            return TerminalText(stringLiteral: "\(preview), +\(sortedPaths.count - limit) more")
        }

        return TerminalText(stringLiteral: preview)
    }
}
