import ArgumentParser
import Noora

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all stored secrets.",
        discussion: "Displays secret names in the default group, a specific group, or a specific subgroup."
    )

    @Option(help: "The group to list. Omit it to list the default group.")
    var group: String?

    @Option(help: "The subgroup to list.")
    var subgroup: String?

    func run() async throws {
        let scopeInput = try CommandInputResolver.resolveListScope(group: group, subgroup: subgroup)
        let vault = SecretVault()
        let scope = try vault.resolveScope(scopeInput, forWrite: false)
        let names = try vault.secretNames(in: scope)

        guard !names.isEmpty else {
            Noora().info(
                .alert(
                    "No secrets stored",
                    takeaways: ["No secrets were found in \(scope.locationDescription)."]
                )
            )

            return
        }

        for name in names {
            print(name)
        }
    }
}
