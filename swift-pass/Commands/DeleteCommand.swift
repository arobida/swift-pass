import ArgumentParser
import Noora

struct DeleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Remove a secret from the Keychain.",
        discussion: "Deletes the stored secret identified by <name>, <group>:<name>, or <group>:<subgroup>:<name>."
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
        let removed = try vault.removeSecret(at: reference)

        if removed {
            Noora().success(
                .alert(
                    "'\(reference.name)' deleted",
                    takeaways: ["The secret was removed from \(scope.locationDescription)."]
                )
            )

            return
        }

        Noora().warning(
            .alert(
                "'\(reference.name)' not found",
                takeaway: "No stored secret matched that name in \(scope.locationDescription)."
            )
        )
    }
}
