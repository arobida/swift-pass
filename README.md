# Swift Pass CLI

`swift-pass` is a macOS command-line tool built with Swift for securely storing, retrieving, listing, and deleting API keys in Apple's native Keychain.

It supports grouped secrets with one level of nesting:
- default group secrets: `swift-pass set "github=token"`
- named group secrets: `swift-pass set "myproject:github=token"`
- subgroup secrets: `swift-pass set "myproject:dev:github=token"`

The project uses Xcode at the repository root. It currently includes:
- the executable target `swift-pass`
- the supporting static library target `swift-passCore`
- the XCTest target `swift-passTests`

## Current Status

Current subcommands:
- `create`
- `set`
- `get`
- `delete`
- `list`
- `groups`
- `doctor`

Right now:
- `create`, `set`, `get`, `delete`, and `list` perform real macOS Keychain operations
- `groups` lists created groups, or the subgroups in a specific group
- `doctor` performs environment and signing checks for Keychain access
- `set` bootstraps the default group on first write and migrates any legacy flat secrets into that default group
- `list` renders a Noora table by default, supports `--plain` for script-friendly output, and supports `-i` / `--interactive` for row selection

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
Group metadata is stored separately in the Keychain under `dev.keys.swift-pass.metadata`.

## Project Structure

- `swift-pass/main.swift` defines the CLI entry point and top-level subcommand registration
- `swift-pass/Commands/` contains one file per subcommand
- `swift-pass/Keychain/` contains Keychain configuration, signing inspection, and storage abstractions
- `swift-pass/Support/` contains shared prompt helpers
- `swift-passTests/` contains the XCTest suite
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

Create a group or subgroup:

```bash
"Build/Products/Debug/swift-pass" create "myproject"
"Build/Products/Debug/swift-pass" create "myproject:dev"
```

Store and read grouped secrets:

```bash
"Build/Products/Debug/swift-pass" set "github=token"
"Build/Products/Debug/swift-pass" set "myproject:github=token"
"Build/Products/Debug/swift-pass" set "myproject:dev:github=token"
"Build/Products/Debug/swift-pass" get "myproject:dev:github"
"Build/Products/Debug/swift-pass" list --group myproject --subgroup dev
"Build/Products/Debug/swift-pass" list --plain
"Build/Products/Debug/swift-pass" list -i
"Build/Products/Debug/swift-pass" groups
"Build/Products/Debug/swift-pass" groups myproject
"Build/Products/Debug/swift-pass" gs --plain
"Build/Products/Debug/swift-pass" groups -i
```

## Testing

Run the full XCTest suite:

```bash
xcodebuild -project "swift-pass.xcodeproj" -scheme "swift-pass" -configuration Debug -derivedDataPath Build test
```

Run one XCTest class:

```bash
xcodebuild -project "swift-pass.xcodeproj" -scheme "swift-pass" -configuration Debug -derivedDataPath Build test -only-testing:"swift-passTests/SecretVaultTests"
```
