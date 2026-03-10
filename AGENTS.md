# AGENTS.md

## Purpose
- This repository contains a macOS command-line tool named `swift-pass`.
- The project is Xcode-based, not SwiftPM-based at the repository root.
- The main app target lives in `swift-pass.xcodeproj` and sources live in `swift-pass/`.
- There is currently one executable target: `swift-pass`.
- There is currently no test target and the Xcode scheme is not configured for the test action.

## Repository Layout
- `swift-pass/main.swift` defines the CLI entry point and top-level subcommand registration.
- `swift-pass/Commands/` contains one file per CLI subcommand.
- `swift-pass/Keychain/` contains keychain access and signing inspection code.
- `swift-pass.xcodeproj/` contains project settings and Swift package dependency wiring.
- `Build/` is derived build output and should generally be treated as generated content.

## Dependencies
- `swift-argument-parser` is used for CLI parsing.
- `Noora` is used for interactive terminal prompts and styled output.
- `Valet` is used for Keychain access.
- Transitive packages include `swift-log`, `Path`, and `Rainbow`.

## Tooling Reality
- There is no `Package.swift` at the repo root.
- There is no `swiftlint` config in the repo.
- There is no `swift-format` config in the repo.
- There are no Cursor rules in `.cursor/rules/`.
- There is no `.cursorrules` file.
- There is no Copilot instruction file at `.github/copilot-instructions.md`.

## Verified Commands
- List schemes and targets:
```bash
xcodebuild -list -project "swift-pass.xcodeproj"
```
- Build the debug executable into the local `Build/` directory:
```bash
xcodebuild -project "swift-pass.xcodeproj" -scheme "swift-pass" -configuration Debug -derivedDataPath Build build
```
- Build the release executable:
```bash
xcodebuild -project "swift-pass.xcodeproj" -scheme "swift-pass" -configuration Release -derivedDataPath Build build
```
- Run the built executable directly:
```bash
"Build/Products/Debug/swift-pass" --help
```
- Clean local build artifacts by deleting `Build/` if needed.

## Test Commands
- Current state: `xcodebuild ... test` fails because the scheme is not configured for testing.
- Verified failing command:
```bash
xcodebuild -project "swift-pass.xcodeproj" -scheme "swift-pass" -configuration Debug -derivedDataPath Build test
```
- Current failure reason: `Scheme swift-pass is not currently configured for the test action.`
- Conclusion: there are no runnable tests in the current repository state.

## Single-Test Guidance
- There is no single-test command that works today because no test target exists.
- If a test target is added later, prefer Xcode test execution over guessing SwiftPM commands.
- Typical future command shape for one XCTest case:
```bash
xcodebuild -project "swift-pass.xcodeproj" -scheme "swift-pass" -configuration Debug -derivedDataPath Build test -only-testing:"swift-passTests/TestCaseName/testExample"
```
- Typical future command shape for one XCTest class:
```bash
xcodebuild -project "swift-pass.xcodeproj" -scheme "swift-pass" -configuration Debug -derivedDataPath Build test -only-testing:"swift-passTests/TestCaseName"
```
- Do not document `swift test` as the primary path unless the repo is converted to a real SwiftPM package.

## Lint And Formatting
- There is no dedicated lint command checked into this repo.
- There is no dedicated formatting command checked into this repo.
- Treat successful `xcodebuild` as the minimum automated validation currently available.
- If you add linting or formatting, document the exact command here and keep it reproducible.

## Recommended Validation Workflow
- For code changes, run the debug build command first.
- If you change CLI behavior, also run `"Build/Products/Debug/swift-pass" --help` or the affected subcommand.
- If you add tests, update the scheme and add concrete test commands to this file.
- If you add scripts referenced by the codebase, verify the paths actually exist before documenting them.

## Platform And Build Settings
- The product type is a macOS command-line tool.
- Target deployment in the target build settings is `macOS 15.6`.
- Project-level build settings still include `MACOSX_DEPLOYMENT_TARGET = 26.0`; do not assume that value is the true app minimum.
- `SWIFT_VERSION` is set to `5.0` in Xcode settings.
- `SWIFT_APPROACHABLE_CONCURRENCY = YES` is enabled.
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` is enabled.
- Hardened runtime is enabled.

## Code Style Overview
- Follow the existing style already present in `swift-pass/` instead of introducing a new house style.
- Prefer small focused `struct`s and `protocol`s over classes unless reference semantics are required.
- Keep files narrowly scoped: one main type per file when practical.
- Use extensions only when they improve clarity; none are currently used in app code.
- Keep CLI command definitions simple and colocate parsing with command behavior.

## Imports
- Import only what the file needs.
- Keep imports at the top of the file.
- Use one import per line.
- In existing code, Apple modules appear before third-party modules when both are present.
- Do not leave unused imports behind.
- Avoid overly broad imports if a narrower module works.

## Formatting
- Use 4-space indentation; do not use tabs.
- Keep braces on the same line as declarations.
- Use trailing commas in multiline arrays and argument lists, matching current files.
- Prefer one blank line between logical sections.
- Keep multiline initializers and function calls vertically aligned and easy to scan.
- Do not introduce decorative comments or banner comments.

## Naming
- Use `UpperCamelCase` for types.
- Use `lowerCamelCase` for functions, properties, parameters, and local variables.
- Command types are named with a `Command` suffix, for example `SetCommand`.
- Protocols use noun-based names that describe capability, for example `SecretStore`.
- Configuration types use descriptive nouns, for example `KeychainConfiguration`.
- Favor names that reflect domain meaning over abbreviations.

## Types
- Prefer explicit stored-property types.
- Prefer explicit function return types, even when inference would work.
- Use tuples sparingly and only when the grouped values are obvious, as in `resolvedSecret() -> (name: String, key: String)`.
- Keep access control intentional; helpers are marked `private` when they are internal implementation details.
- Prefer value types unless there is a clear reason not to.

## Control Flow
- Prefer `guard` for early exits and validation failures.
- Keep happy-path logic shallow.
- Split non-trivial parsing or validation into small helper functions.
- Return early after emitting terminal output when further work is unnecessary.

## Error Handling
- Use `throws` for fallible operations instead of returning sentinel values.
- For CLI argument validation, use `ValidationError`.
- For domain-specific failures, define typed errors that can provide `LocalizedError.errorDescription`.
- Prefer precise, user-readable error messages.
- Use `try?` only when failure is truly optional and the fallback behavior is intentional.
- Avoid `fatalError`; the existing code uses `preconditionFailure` only for impossible configuration states.

## CLI And UX Conventions
- Subcommands conform to `AsyncParsableCommand`.
- Each command defines a static `configuration` with `commandName`, `abstract`, and usually `discussion`.
- Argument and prompt help text should be specific and action-oriented.
- Use `Noora` for user-facing alerts, prompts, warnings, and success messages.
- Match the existing tone: direct, helpful, and concise.
- Prefer actionable takeaways in terminal output.

## Keychain And Security Conventions
- Keep keychain-related logic under `swift-pass/Keychain/`.
- Preserve the service-name-driven configuration pattern used by `KeychainConfiguration`.
- Be careful with entitlements, signing inspection, and Keychain access-group logic.
- Do not log or print secrets unless the command explicitly requires revealing them.
- Treat security-sensitive defaults conservatively.

## File Editing Guidance
- Respect the current directory structure.
- Do not add build-system alternatives unless the repo is intentionally being migrated.
- Do not document nonexistent scripts as if they are supported workflows.
- If you add tests, add a test target and update this file immediately.
- If you add lint or format tooling, add the exact command and config path.

## Agent Reminders
- Before making build or test claims, verify them with `xcodebuild`.
- Mention that there are currently no Cursor or Copilot repo rules when relevant.
- Prefer repository facts over generic Swift advice.
- Keep this file in sync with the actual project configuration.
