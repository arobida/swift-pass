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
            if let catalog = try vault.currentCatalog() {
                catalogStatus = "The group catalog is readable and the default group is '\(catalog.defaultGroup)'."
            } else {
                catalogStatus = "The group catalog has not been initialized yet. It will be created on the first set or create command."
            }
        } catch {
            Noora().warning(
                .alert(
                    "The group catalog could not be read",
                    takeaway: TerminalText(stringLiteral: error.localizedDescription)
                ),
                .alert(
                    "Secret storage access is available",
                    takeaway: "The Keychain service itself is reachable, but group metadata needs repair before grouped commands can be used."
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
                ]
            )
        )
    }
}
