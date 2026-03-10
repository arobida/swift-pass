import ArgumentParser
import Noora

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all stored secrets.",
        discussion: "Displays the names of every secret currently stored in the Keychain."
    )

    func run() async throws {
        Noora().info(
            .alert(
                "No secrets listed",
                takeaways: ["Keychain integration is not implemented yet. \(.command("list")) is a placeholder."]
            )
        )
    }
}
