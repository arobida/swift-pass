//
//  main.swift
//  swift-pass
//
//  Created by Andrew Robida on 3/8/26.
//

import Foundation
import ArgumentParser
import Noora

@available(macOS 15.0, *)
struct SwiftPass: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-pass",
        abstract: "Securely store and retrieve API keys using Apple's Keychain.",
        discussion: "Use subcommands to manage your secrets. Run a subcommand with --help for details.",
        subcommands: [
            SetCommand.self,
            GetCommand.self,
            DeleteCommand.self,
            ListCommand.self,
            DoctorCommand.self,
        ]
    )
}

SwiftPass.main()
