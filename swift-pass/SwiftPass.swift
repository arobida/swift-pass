import ArgumentParser

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
@main
struct SwiftPass: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-pass",
        abstract: "Securely store and retrieve API keys using Apple's Keychain.",
        discussion: "Use subcommands to manage your secrets. Run a subcommand with --help for details.",
        subcommands: [
            CreateCommand.self,
            SetCommand.self,
            GetCommand.self,
            DeleteCommand.self,
            ListCommand.self,
            GroupsCommand.self,
            DoctorCommand.self,
        ]
    )
}
