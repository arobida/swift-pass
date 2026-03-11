import ArgumentParser

struct GetCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Retrieve a secret from the Keychain.",
        discussion: "Looks up a stored secret by name and prints its value. Use <name>, <group>:<name>, or <group>:<subgroup>:<name>."
    )

    @Argument(help: "The secret reference in the format <name>, <group>:<name>, or <group>:<subgroup>:<name>.")
    var secret: String?

    @Option(help: "The group that owns the secret.")
    var group: String?

    @Option(help: "The subgroup that owns the secret.")
    var subgroup: String?

    @Option(help: "The secret name.")
    var name: String?

    func run() async throws {
        let input = try CommandInputResolver.resolveNamedSecretInput(
            shorthand: secret,
            group: group,
            subgroup: subgroup,
            name: name
        )
        let vault = SecretVault()
        let scope = try vault.resolveScope(input.scope, forWrite: false)
        let reference = try SecretReference(scope: scope, name: input.name)
        print(try vault.secret(at: reference))
    }
}
