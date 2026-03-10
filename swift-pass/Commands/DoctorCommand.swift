import ArgumentParser
import Noora

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check that swift-pass is configured correctly.",
        discussion: "Runs a series of checks to verify the CLI is working and the environment is ready."
    )

    func run() async throws {
        let store = ValetSecretStore()
        let expectedServiceName = store.configuration.serviceName
        let signingStatus = try? CurrentProcessSigningInspector().inspect()
        let hasExpectedEntitlements = signingStatus?.hasExpectedKeychainEntitlements(for: expectedServiceName) ?? false

        if signingStatus == nil {
            Noora().warning(
                .alert(
                    "Could not inspect signing information",
                    takeaway: "Run the Xcode-generated binary directly if you want doctor to confirm embedded keychain entitlements."
                ),
                .alert(
                    "Keychain access still needs to be verified",
                    takeaway: "Rerun \(.command("doctor")) from a built executable after signing is configured."
                )
            )

            return
        }

        guard hasExpectedEntitlements else {
            Noora().warning(
                .alert(
                    "Current executable is missing expected keychain entitlements",
                    takeaway: "The running binary at '\(signingStatus?.executablePath ?? CommandLine.arguments[0])' does not embed the expected '\(expectedServiceName)' identifiers."
                ),
                .alert(
                    "Run the signed Xcode build",
                    takeaway: "Build with `xcodebuild -project \"swift-pass.xcodeproj\" -scheme \"swift-pass\" -configuration Debug -derivedDataPath Build build` and rerun the built executable from `Build/Products/Debug/swift-pass`."
                )
            )

            return
        }

        guard store.canAccessKeychain() else {
            Noora().warning(
                .alert(
                    "Keychain access is not available",
                    takeaway: "Valet is configured with the '\(expectedServiceName)' service identifier."
                ),
                .alert(
                    "Xcode signing still needs keychain capabilities",
                    takeaway: "Enable Keychain Sharing for the Xcode target and attach a target entitlements file that includes the expected keychain access group."
                ),
                .alert(
                    "Verify signing after setup",
                    takeaway: "After signing is configured, rerun \(.command("doctor")) to verify access."
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
                    "The running executable is signed with the expected keychain entitlements for '\(expectedServiceName)'.",
                    "Valet can access the Keychain with the '\(expectedServiceName)' service identifier.",
                ]
            )
        )
    }
}
