import Dispatch
import ArgumentParser

@available(macOS 10.15, *)
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

if #available(macOS 10.15, *) {
    let semaphore = DispatchSemaphore(value: 0)

    Task {
        await SwiftPass.main()
        semaphore.signal()
    }

    semaphore.wait()
} else {
    preconditionFailure("swift-pass requires macOS 10.15 or newer.")
}
