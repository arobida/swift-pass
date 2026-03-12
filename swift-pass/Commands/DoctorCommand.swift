import ArgumentParser
import Foundation
import Noora

private enum DoctorCheckLevel {
    case success
    case warning
    case error
}

private struct DoctorCheckResult {
    let level: DoctorCheckLevel
    let title: TerminalText
    let takeaway: TerminalText?
}

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check that swift-pass is configured correctly.",
        discussion: "Runs a series of checks to verify the CLI is working and the environment is ready."
    )

    func run() async throws {
        let vault = SecretVault()
        let store = ValetSecretStore()
        let expectedServiceName = store.configuration.serviceName
        let metadataServiceName = KeychainGroupCatalogStore().configuration.serviceName
        let signingStatus = try? CurrentProcessSigningInspector().inspect()
        let hasExpectedSigning = signingStatus?.hasExpectedKeychainEntitlements(for: expectedServiceName) ?? false
        let canAccessSecretStore = vault.canAccessSecretStore()
        let canAccessCatalogStore = vault.canAccessCatalogStore()

        let keychainResult = keychainCheckResult(
            signingStatus: signingStatus,
            hasExpectedSigning: hasExpectedSigning,
            canAccessSecretStore: canAccessSecretStore,
            canAccessCatalogStore: canAccessCatalogStore,
            metadataServiceName: metadataServiceName
        )

        let results: [DoctorCheckResult]

        if keychainResult.level == .error {
            results = [
                keychainResult,
                DoctorCheckResult(
                    level: .error,
                    title: "Default group could not be verified.",
                    takeaway: "Fix the Keychain integration first, then rerun \(TerminalText.Component.command("swift-pass doctor"))."
                ),
                DoctorCheckResult(
                    level: .error,
                    title: "Secret parent groups could not be verified.",
                    takeaway: "Fix the Keychain integration first, then rerun \(TerminalText.Component.command("swift-pass doctor"))."
                ),
            ]
        } else {
            let status = try vault.doctorStatus()
            results = [
                keychainResult,
                defaultGroupCheckResult(for: status),
                secretParentageCheckResult(for: status),
            ]
        }

        let noora = Noora()

        for result in results {
            render(result, using: noora)
        }
    }

    private func keychainCheckResult(
        signingStatus: CurrentProcessSigningStatus?,
        hasExpectedSigning: Bool,
        canAccessSecretStore: Bool,
        canAccessCatalogStore: Bool,
        metadataServiceName: String
    ) -> DoctorCheckResult {
        guard let signingStatus else {
            if canAccessSecretStore && canAccessCatalogStore {
                return DoctorCheckResult(
                    level: .warning,
                    title: "Keychain integration is working.",
                    takeaway: "swift-pass could not inspect this binary’s signing details. Run the built executable directly if you want to verify that too."
                )
            }

            return DoctorCheckResult(
                level: .error,
                title: "Keychain integration is not working.",
                takeaway: "swift-pass could not verify this binary’s signing details or access its Keychain storage."
            )
        }

        guard hasExpectedSigning else {
            return DoctorCheckResult(
                level: .error,
                title: "Keychain integration is not working.",
                takeaway: "The binary at '\(signingStatus.executablePath)' is not signed for this installation. Rebuild and run the generated executable again."
            )
        }

        guard canAccessSecretStore else {
            return DoctorCheckResult(
                level: .error,
                title: "Keychain integration is not working.",
                takeaway: "swift-pass could not access its secret storage. Run it from your normal signed-in macOS session and try again."
            )
        }

        guard canAccessCatalogStore else {
            return DoctorCheckResult(
                level: .error,
                title: "Keychain integration is not working.",
                takeaway: "swift-pass could not access its group metadata store '\(metadataServiceName)'."
            )
        }

        return DoctorCheckResult(
            level: .success,
            title: "Keychain integration is working.",
            takeaway: nil
        )
    }

    private func defaultGroupCheckResult(for status: DoctorStatus) -> DoctorCheckResult {
        guard let catalog = status.catalog else {
            return DoctorCheckResult(
                level: .warning,
                title: "No default group is configured.",
                takeaway: "Run \(TerminalText.Component.command("swift-pass create default")) to initialize it."
            )
        }

        return DoctorCheckResult(
            level: .success,
            title: "Default group is configured.",
            takeaway: "Default group: '\(catalog.defaultGroup)'."
        )
    }

    private func secretParentageCheckResult(for status: DoctorStatus) -> DoctorCheckResult {
        let orphanedReferences = status.orphanedSecretReferences

        guard orphanedReferences.isEmpty else {
            return DoctorCheckResult(
                level: .warning,
                title: "Some secrets are not attached to configured groups.",
                takeaway: "Missing parent group or subgroup for: \(formattedSecretPaths(orphanedReferences.map(\.displayPath)))."
            )
        }

        return DoctorCheckResult(
            level: .success,
            title: "All secrets belong to configured groups.",
            takeaway: nil
        )
    }

    private func render(_ result: DoctorCheckResult, using noora: Noora) {
        switch result.level {
        case .success:
            noora.success(
                .alert(
                    result.title,
                    takeaways: takeaways(for: result)
                )
            )
        case .warning:
            noora.warning(
                .alert(
                    result.title,
                    takeaway: result.takeaway
                )
            )
        case .error:
            noora.error(
                .alert(
                    result.title,
                    takeaways: takeaways(for: result)
                )
            )
        }
    }

    private func takeaways(for result: DoctorCheckResult) -> [TerminalText] {
        guard let takeaway = result.takeaway else {
            return []
        }

        return [takeaway]
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
