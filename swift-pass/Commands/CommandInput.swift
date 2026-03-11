import ArgumentParser
import Foundation

struct SetCommandInput: Equatable {
    let scope: SecretScopeInput
    let name: String
    let value: String
}

struct NamedSecretInput: Equatable {
    let scope: SecretScopeInput
    let name: String
}

struct CreateScopeInput: Equatable {
    let group: String
    let subgroup: String?

    func resolvedScope() throws -> SecretScope {
        try SecretScope(group: group, subgroup: subgroup)
    }
}

enum CommandInputResolver {
    static func resolveSetInput(
        entry: String?,
        group: String?,
        subgroup: String?,
        name: String?,
        value: String?,
        prompter: UserPrompter
    ) throws -> SetCommandInput {
        if let entry {
            guard group == nil, subgroup == nil, name == nil, value == nil else {
                throw ValidationError("Do not mix shorthand input with --group, --subgroup, --name, or --value.")
            }

            let parts = entry.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)

            guard parts.count == 2 else {
                throw ValidationError("The set command expects <name>=<value>, <group>:<name>=<value>, or <group>:<subgroup>:<name>=<value>.")
            }

            let reference = try parseSetReference(String(parts[0]))
            let resolvedValue = try validatedValue(String(parts[1]))
            return SetCommandInput(scope: reference.scope, name: reference.name, value: resolvedValue)
        }

        guard subgroup == nil || group != nil else {
            throw ValidationError("The --subgroup option requires --group.")
        }

        let scope = SecretScopeInput(group: group, subgroup: subgroup)

        if let name, let value {
            return SetCommandInput(
                scope: scope,
                name: try validatedName(name),
                value: try validatedValue(value)
            )
        }

        if name == nil, let value {
            let inline = value.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)

            guard inline.count == 2 else {
                throw ValidationError("Provide both --name and --value, or use --value in the format <name>:<value>.")
            }

            return SetCommandInput(
                scope: scope,
                name: try validatedName(String(inline[0])),
                value: try validatedValue(String(inline[1]))
            )
        }

        guard value == nil else {
            throw ValidationError("The --value option requires a secret name.")
        }

        let resolvedName = prompter.textInput(
            title: "Secret name",
            prompt: "What name should identify this secret?",
            description: "Examples: openai, github, stripe",
            defaultValue: nil
        )
        let resolvedValue = prompter.textInput(
            title: "Secret value",
            prompt: "What value should be stored for '\(resolvedName)'?",
            description: "Paste the API key you want swift-pass to store in the macOS Keychain.",
            defaultValue: nil
        )

        return SetCommandInput(
            scope: scope,
            name: try validatedName(resolvedName),
            value: try validatedValue(resolvedValue)
        )
    }

    static func resolveNamedSecretInput(
        shorthand: String?,
        group: String?,
        subgroup: String?,
        name: String?
    ) throws -> NamedSecretInput {
        if let shorthand {
            guard group == nil, subgroup == nil, name == nil else {
                throw ValidationError("Do not mix shorthand input with --group, --subgroup, or --name.")
            }

            return try parseNamedSecretReference(shorthand)
        }

        guard subgroup == nil || group != nil else {
            throw ValidationError("The --subgroup option requires --group.")
        }

        guard let name else {
            throw ValidationError("Provide a secret name or use the shorthand positional argument.")
        }

        return NamedSecretInput(
            scope: SecretScopeInput(group: group, subgroup: subgroup),
            name: try validatedName(name)
        )
    }

    static func resolveCreateInput(
        shorthand: String?,
        group: String?,
        subgroup: String?
    ) throws -> CreateScopeInput {
        if let shorthand {
            guard group == nil, subgroup == nil else {
                throw ValidationError("Do not mix shorthand input with --group or --subgroup.")
            }

            let parts = shorthand.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

            switch parts.count {
            case 1:
                return CreateScopeInput(group: try validatedGroup(parts[0]), subgroup: nil)
            case 2:
                return CreateScopeInput(group: try validatedGroup(parts[0]), subgroup: try validatedSubgroup(parts[1]))
            default:
                throw ValidationError("The create command expects <group> or <group>:<subgroup>.")
            }
        }

        guard let group else {
            throw ValidationError("Provide a group to create.")
        }

        return CreateScopeInput(
            group: try validatedGroup(group),
            subgroup: try subgroup.map(validatedSubgroup)
        )
    }

    static func resolveListScope(group: String?, subgroup: String?) throws -> SecretScopeInput {
        guard subgroup == nil || group != nil else {
            throw ValidationError("The --subgroup option requires --group.")
        }

        return SecretScopeInput(group: group, subgroup: subgroup)
    }

    private static func parseSetReference(_ value: String) throws -> NamedSecretInput {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

        switch parts.count {
        case 1:
            return NamedSecretInput(scope: SecretScopeInput(), name: try validatedName(parts[0]))
        case 2:
            return NamedSecretInput(
                scope: SecretScopeInput(group: try validatedGroup(parts[0])),
                name: try validatedName(parts[1])
            )
        case 3:
            return NamedSecretInput(
                scope: SecretScopeInput(
                    group: try validatedGroup(parts[0]),
                    subgroup: try validatedSubgroup(parts[1])
                ),
                name: try validatedName(parts[2])
            )
        default:
            throw ValidationError("The set command expects <name>, <group>:<name>, or <group>:<subgroup>:<name> before '='.")
        }
    }

    private static func parseNamedSecretReference(_ value: String) throws -> NamedSecretInput {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false).map(String.init)

        switch parts.count {
        case 1:
            return NamedSecretInput(scope: SecretScopeInput(), name: try validatedName(parts[0]))
        case 2:
            return NamedSecretInput(
                scope: SecretScopeInput(group: try validatedGroup(parts[0])),
                name: try validatedName(parts[1])
            )
        case 3:
            return NamedSecretInput(
                scope: SecretScopeInput(
                    group: try validatedGroup(parts[0]),
                    subgroup: try validatedSubgroup(parts[1])
                ),
                name: try validatedName(parts[2])
            )
        default:
            throw ValidationError("The command expects <name>, <group>:<name>, or <group>:<subgroup>:<name>.")
        }
    }

    private static func validatedGroup(_ value: String) throws -> String {
        try validatedIdentifier(value, kind: "group")
    }

    private static func validatedSubgroup(_ value: String) throws -> String {
        try validatedIdentifier(value, kind: "subgroup")
    }

    private static func validatedName(_ value: String) throws -> String {
        try validatedIdentifier(value, kind: "secret name")
    }

    private static func validatedValue(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw ValidationError("The secret value cannot be empty.")
        }

        return value
    }

    private static func validatedIdentifier(_ value: String, kind: String) throws -> String {
        do {
            return try SecretScope.validatedIdentifier(value, kind: kind)
        } catch let error as GroupCatalogError {
            throw ValidationError(error.localizedDescription)
        }
    }
}
