# swift-pass

`swift-pass` is a macOS command-line tool for storing and retrieving secrets from Apple's Keychain with a simple, scope-aware CLI.

It supports a default group, named groups, and one level of subgroup nesting so you can organize credentials by project and environment without leaving the terminal.

## Features

- Store, read, list, and delete secrets from the macOS Keychain
- Organize secrets by default group, named group, or subgroup scope
- Create groups and subgroups explicitly with `create`
- Browse secrets and groups with plain-text or interactive Noora-powered output
- Run `doctor` to inspect signing, Keychain access, catalog health, and orphaned entries
- Bootstrap the default catalog automatically on first write
- Migrate legacy flat secrets into the default group during bootstrap

## Installation

`swift-pass` is currently built from source with Xcode at the repository root.

### Requirements

- macOS
- Xcode with command line tools installed

### Build From Source

1. Clone the repository.
2. List available schemes if needed:

```bash
xcodebuild -list -project "swift-pass.xcodeproj"
```

3. Build the debug executable:

```bash
xcodebuild -project "swift-pass.xcodeproj" -scheme "swift-pass" -configuration Debug -derivedDataPath Build build
```

4. Run the built binary:

```bash
"Build/Products/Debug/swift-pass" --help
```

## Usage

### Secret Scopes

- Default group: `name`
- Named group: `group:name`
- Subgroup: `group:subgroup:name`

### Common Commands

Store secrets:

```bash
"Build/Products/Debug/swift-pass" set "github=token"
"Build/Products/Debug/swift-pass" set "myproject:github=token"
"Build/Products/Debug/swift-pass" set "myproject:dev:github=token"
```

Read and delete secrets:

```bash
"Build/Products/Debug/swift-pass" get "myproject:dev:github"
"Build/Products/Debug/swift-pass" delete "myproject:dev:github"
```

Create scopes:

```bash
"Build/Products/Debug/swift-pass" create "myproject"
"Build/Products/Debug/swift-pass" create "myproject:dev"
```

List secrets:

```bash
"Build/Products/Debug/swift-pass" list
"Build/Products/Debug/swift-pass" list --group myproject --subgroup dev
"Build/Products/Debug/swift-pass" list --plain
"Build/Products/Debug/swift-pass" list --interactive
```

List groups and subgroups:

```bash
"Build/Products/Debug/swift-pass" groups
"Build/Products/Debug/swift-pass" groups myproject
"Build/Products/Debug/swift-pass" gs --plain
"Build/Products/Debug/swift-pass" groups --interactive
```

Run diagnostics:

```bash
"Build/Products/Debug/swift-pass" doctor
```

## Tech Stack

- Swift
- Xcode project-based build setup
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) for command parsing
- [Noora](https://github.com/tuist/Noora) for prompts, tables, and terminal UX
- [Valet](https://github.com/square/Valet) plus the macOS Security framework for Keychain access
- XCTest for automated tests

## Project Structure

```text
swift-pass/
  Commands/    CLI subcommands and argument resolution
  Keychain/    Keychain access, scope catalog, signing checks, and vault logic
  Support/     Shared prompting helpers
  main.swift   CLI entry point
swift-passTests/  XCTest coverage for parsing, listing, groups, and vault behavior
swift-pass.xcodeproj/  Xcode project and package wiring
Build/  Local derived build output
```

## Development

Build the project:

```bash
xcodebuild -project "swift-pass.xcodeproj" -scheme "swift-pass" -configuration Debug -derivedDataPath Build build
```

Run the full test suite:

```bash
xcodebuild -project "swift-pass.xcodeproj" -scheme "swift-pass" -configuration Debug -derivedDataPath Build test
```

Run a single test class:

```bash
xcodebuild -project "swift-pass.xcodeproj" -scheme "swift-pass" -configuration Debug -derivedDataPath Build test -only-testing:"swift-passTests/SecretVaultTests"
```

## Contributing

Contributions are welcome.

1. Fork the repository and create a focused branch.
2. Follow the existing Swift style and keep changes narrowly scoped.
3. Add or update tests when behavior changes.
4. Verify your work with `xcodebuild` before opening a pull request.
5. Update docs when commands, workflows, or project structure change.

## License

No license file is currently present in this repository.
