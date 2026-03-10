import ArgumentParser
import Noora

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all stored secrets.",
        discussion: "Displays the names of every secret currently stored in the Keychain."
    )

    func run() async throws {
        let store = ValetSecretStore()
        let names = try store.secretNames()

        guard !names.isEmpty else {
            Noora().info(
                .alert(
                    "No secrets stored",
                    takeaways: ["The macOS Keychain does not have any swift-pass entries yet."]
                )
            )

            return
        }

        for name in names {
            print(name)
        }
    }
}
