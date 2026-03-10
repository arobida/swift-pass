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
        Noora().warning(
            .alert(
                "'\(name)' not deleted",
                takeaway: "Keychain integration is not implemented yet. \(.command("delete")) is a placeholder."
            )
        )
    }
}
