import ArgumentParser
import Noora

struct SetCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Store a secret in the Keychain.",
        discussion: "Provide a secret as <name>:<key>. If omitted, Noora will prompt for the name and key separately."
    )

    @Argument(help: "A secret entry in the format <name>:<key>.")
    var entry: String?

    func run() async throws {
        let secret = try resolvedSecret()

        Noora().warning(
            .alert(
                "'\(secret.name)' not stored",
                takeaway: "Keychain integration is not implemented yet. \(.command("set")) is a placeholder."
            )
        )
    }

    private func resolvedSecret() throws -> (name: String, key: String) {
        if let entry {
            return try parse(entry: entry)
        }

        let noora = Noora()
        let name = noora.textPrompt(
            title: "Secret name",
            prompt: "What name should identify this secret?",
            description: "Examples: openai, github, stripe",
            validationRules: [NonEmptyValidationRule(error: "Secret name cannot be empty.")]
        )
        let key = noora.textPrompt(
            title: "Secret key",
            prompt: "What key should be stored for '\(name)'?",
            description: "Paste the API key you want swift-pass to store later.",
            validationRules: [NonEmptyValidationRule(error: "Secret key cannot be empty.")]
        )

        return (name: name, key: key)
    }

    private func parse(entry: String) throws -> (name: String, key: String) {
        let parts = entry.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)

        guard parts.count == 2 else {
            throw ValidationError("The set command expects <name>:<key>.")
        }

        let name = String(parts[0])
        let key = String(parts[1])

        guard !name.isEmpty else {
            throw ValidationError("The secret name cannot be empty.")
        }

        guard !key.isEmpty else {
            throw ValidationError("The secret key cannot be empty.")
        }

        return (name: name, key: key)
    }
}
