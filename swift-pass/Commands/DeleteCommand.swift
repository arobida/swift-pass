import ArgumentParser
import Noora

struct DeleteCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Remove a secret from the Keychain.",
        discussion: "Deletes the stored secret identified by name."
    )

    @Argument(help: "The name of the secret to delete.")
    var name: String

    func run() async throws {
        let store = ValetSecretStore()
        let removed = try store.removeSecret(named: name)

        if removed {
            Noora().success(
                .alert(
                    "'\(name)' deleted",
                    takeaways: ["The secret was removed from the macOS Keychain."]
                )
            )

            return
        }

        Noora().warning(
            .alert(
                "'\(name)' not found",
                takeaway: "No stored secret matched that name in the macOS Keychain."
            )
        )
    }
}
