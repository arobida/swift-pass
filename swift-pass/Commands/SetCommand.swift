import ArgumentParser
import Noora

struct SetCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Store a secret in the Keychain.",
        discussion: "Provide a secret as <name>=<value>, <group>:<name>=<value>, or <group>:<subgroup>:<name>=<value>. If omitted, Noora will prompt for the name and value separately."
    )

    @Argument(help: "A secret entry in the format <name>=<value>, <group>:<name>=<value>, or <group>:<subgroup>:<name>=<value>.")
    var entry: String?

    @Option(help: "The group that owns the secret.")
    var group: String?

    @Option(help: "The subgroup that owns the secret.")
    var subgroup: String?

    @Option(help: "The secret name. If omitted, --value may use the format <name>:<value>.")
    var name: String?

    @Option(help: "The secret value, or <name>:<value> when --name is omitted.")
    var value: String?

    func run() async throws {
        let prompter = NooraPrompter()
        let input = try CommandInputResolver.resolveSetInput(
            entry: entry,
            group: group,
            subgroup: subgroup,
            name: name,
            value: value,
            prompter: prompter
        )
        let vault = SecretVault(prompter: prompter)
        let scope = try vault.resolveScope(input.scope, forWrite: true)
        let reference = try SecretReference(scope: scope, name: input.name)
        let result = try vault.setSecret(input.value, at: reference)

        switch result {
        case .created:
            Noora().success(
                .alert(
                    "'\(reference.name)' saved",
                    takeaways: ["Stored '\(reference.name)' in \(scope.locationDescription)."]
                )
            )
        case .updated:
            Noora().success(
                .alert(
                    "'\(reference.name)' saved",
                    takeaways: ["Updated '\(reference.name)' in \(scope.locationDescription)."]
                )
            )
        }
    }
}
