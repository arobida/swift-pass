import ArgumentParser

struct GetCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Retrieve a secret from the Keychain.",
        discussion: "Looks up a stored secret by name and prints its value."
    )

    @Argument(help: "The name of the secret to retrieve.")
    var name: String

    func run() async throws {
        let store = ValetSecretStore()
        let secret = try store.secret(named: name)
        print(secret)
    }
}
