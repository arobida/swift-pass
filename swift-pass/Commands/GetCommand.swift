import ArgumentParser
import Noora

struct GetCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Retrieve a secret from the Keychain.",
        discussion: "Looks up a stored secret by name and prints its value."
    )

    @Argument(help: "The name of the secret to retrieve.")
    var name: String

    func run() async throws {
        Noora().warning(
            .alert(
                "'\(name)' not retrieved",
                takeaway: "Keychain integration is not implemented yet. \(.command("get")) is a placeholder."
            )
        )
    }
}
