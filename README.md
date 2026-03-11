# Swift Pass CLI

`swift-pass` is a macOS command-line tool built with Swift for securely storing, retrieving, listing, and deleting API keys in Apple's native Keychain.

The project uses Xcode at the repository root and currently builds a single executable target: `swift-pass`.

## Current Status

Current subcommands:
- `set`
- `get`
- `delete`
- `list`
- `doctor`

Right now:
- `set`, `get`, `delete`, and `list` perform real macOS Keychain operations
- `doctor` performs environment and signing checks for Keychain access

## Architecture Decision

Chosen stack:
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) for CLI structure and command parsing
- [Noora](https://github.com/tuist/Noora) for interactive terminal UX
- [Valet](https://github.com/square/Valet) for Keychain storage and access checks

## Swift Packages

The Swift packages currently used by `swift-pass` are:

### CLI Foundation

[`swift-argument-parser`](https://github.com/apple/swift-argument-parser) is the foundation of the CLI.

It handles:
- command parsing
- subcommands
- flags and options
- help text

### Terminal UX

[`Noora`](https://github.com/tuist/Noora) provides the interactive terminal experience.

It is used for:
- prompts
- alerts
- warnings
- success output
- general terminal UI polish

Important:
Noora is not the command parser. It is the presentation layer on top of `swift-argument-parser`.

Reference:
- [Noora repository](https://github.com/tuist/Noora)
- [Prompt documentation](https://noora.tuist.dev/components/prompts/yes-or-no-choice)

### Keychain Integration

[`Valet`](https://github.com/square/Valet) is the Apple Keychain integration layer.

It is responsible for:
- configuring Keychain access
- checking whether the current process can access the Keychain

The CLI uses the macOS Security framework for the underlying add/get/delete/list item operations, scoped to the `dev.keys.swift-pass` service name.

The Xcode target is signed with a Keychain Sharing entitlement for `$(AppIdentifierPrefix)dev.keys.swift-pass` so the built binary and the Keychain service identifier stay aligned.

## Project Structure

- `swift-pass/main.swift` defines the CLI entry point and top-level subcommand registration
- `swift-pass/Commands/` contains one file per subcommand
- `swift-pass/Keychain/` contains Keychain configuration, signing inspection, and storage abstractions
- `swift-pass.xcodeproj/` contains the Xcode project and package dependency wiring
- `Build/` contains derived build output

## Building

List project targets and schemes:

```bash
xcodebuild -list -project "swift-pass.xcodeproj"
```

Build the debug executable into the local `Build/` directory:

```bash
xcodebuild -project "swift-pass.xcodeproj" -scheme "swift-pass" -configuration Debug -derivedDataPath Build build
```

Build the release executable:

```bash
xcodebuild -project "swift-pass.xcodeproj" -scheme "swift-pass" -configuration Release -derivedDataPath Build build
```

## Running

Show top-level help:

```bash
"Build/Products/Debug/swift-pass" --help
```

Run a specific subcommand:

```bash
"Build/Products/Debug/swift-pass" doctor
```

## Testing

There is currently no runnable test target configured for the Xcode scheme.

This command currently fails:

```bash
xcodebuild -project "swift-pass.xcodeproj" -scheme "swift-pass" -configuration Debug -derivedDataPath Build test
```

Current failure:

```text
Scheme swift-pass is not currently configured for the test action.
```
