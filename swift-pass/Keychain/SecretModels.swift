import Foundation

struct SecretScopeInput: Equatable, Hashable {
    let group: String?
    let subgroup: String?

    init(group: String? = nil, subgroup: String? = nil) {
        self.group = group?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.subgroup = subgroup?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct SecretScope: Codable, Equatable, Hashable {
    static let reservedDefaultGroupName = "default"

    let group: String
    let subgroup: String?

    init(group: String, subgroup: String? = nil) throws {
        self.group = try Self.validatedIdentifier(group, kind: "group")
        self.subgroup = try subgroup.map { try Self.validatedIdentifier($0, kind: "subgroup") }
    }

    static var defaultScope: SecretScope {
        try! SecretScope(group: reservedDefaultGroupName)
    }

    var displayPath: String {
        if let subgroup {
            return "\(group):\(subgroup)"
        }

        return group
    }

    var locationDescription: String {
        if let subgroup {
            return "group '\(group)' / subgroup '\(subgroup)'"
        }

        return "group '\(group)'"
    }

    static func validatedIdentifier(_ value: String, kind: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw GroupCatalogError.invalidIdentifier(kind: kind, value: value)
        }

        guard !trimmed.contains(":") && !trimmed.contains("=") else {
            throw GroupCatalogError.invalidIdentifier(kind: kind, value: trimmed)
        }

        return trimmed
    }
}

struct SecretReference: Codable, Equatable, Hashable {
    let scope: SecretScope
    let name: String

    init(scope: SecretScope, name: String) throws {
        self.scope = scope
        self.name = try Self.validatedName(name)
    }

    var displayPath: String {
        "\(scope.displayPath):\(name)"
    }

    private static func validatedName(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            throw GroupCatalogError.invalidIdentifier(kind: "secret name", value: value)
        }

        guard !trimmed.contains(":") && !trimmed.contains("=") else {
            throw GroupCatalogError.invalidIdentifier(kind: "secret name", value: trimmed)
        }

        return trimmed
    }
}

struct SecretListEntry: Equatable {
    let reference: SecretReference
    let modificationDate: Date?
}

struct GroupListEntry: Equatable {
    let group: String
    let subgroups: [String]
    let secretCount: Int
}

struct SubgroupListEntry: Equatable {
    let scope: SecretScope
    let secretCount: Int
}

struct GroupCatalog: Codable, Equatable {
    struct GroupEntry: Codable, Equatable {
        let name: String
        var subgroups: [String]
    }

    static let currentSchemaVersion = 1

    let schemaVersion: Int
    var defaultGroup: String
    var groups: [GroupEntry]

    static func bootstrappedDefault() -> GroupCatalog {
        GroupCatalog(
            schemaVersion: currentSchemaVersion,
            defaultGroup: SecretScope.reservedDefaultGroupName,
            groups: [
                GroupEntry(name: SecretScope.reservedDefaultGroupName, subgroups: []),
            ]
        )
    }

    func validated() throws -> GroupCatalog {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw GroupCatalogError.catalogCorrupted("unsupported schema version \(schemaVersion)")
        }

        let validatedDefaultGroup = try SecretScope.validatedIdentifier(defaultGroup, kind: "default group")
        var validatedGroups: [GroupEntry] = []
        var seenGroups: Set<String> = []

        for group in groups {
            let groupName = try SecretScope.validatedIdentifier(group.name, kind: "group")

            guard seenGroups.insert(groupName).inserted else {
                throw GroupCatalogError.catalogCorrupted("duplicate group '\(groupName)'")
            }

            var seenSubgroups: Set<String> = []
            let subgroups = try group.subgroups.map { subgroup in
                let subgroupName = try SecretScope.validatedIdentifier(subgroup, kind: "subgroup")

                guard seenSubgroups.insert(subgroupName).inserted else {
                    throw GroupCatalogError.catalogCorrupted("duplicate subgroup '\(subgroupName)' in '\(groupName)'")
                }

                return subgroupName
            }

            validatedGroups.append(GroupEntry(name: groupName, subgroups: subgroups.sorted()))
        }

        guard seenGroups.contains(validatedDefaultGroup) else {
            throw GroupCatalogError.defaultGroupNotConfigured
        }

        return GroupCatalog(
            schemaVersion: schemaVersion,
            defaultGroup: validatedDefaultGroup,
            groups: validatedGroups.sorted { $0.name < $1.name }
        )
    }

    func containsGroup(_ name: String) -> Bool {
        groups.contains { $0.name == name }
    }

    func containsSubgroup(_ subgroup: String, in group: String) -> Bool {
        groups.first(where: { $0.name == group })?.subgroups.contains(subgroup) ?? false
    }

    func scopeExists(_ scope: SecretScope) -> Bool {
        if let subgroup = scope.subgroup {
            return containsSubgroup(subgroup, in: scope.group)
        }

        return containsGroup(scope.group)
    }

    mutating func addGroup(_ name: String) {
        guard !containsGroup(name) else {
            return
        }

        groups.append(GroupEntry(name: name, subgroups: []))
        groups.sort { $0.name < $1.name }
    }

    mutating func addSubgroup(_ subgroup: String, to group: String) throws {
        guard let index = groups.firstIndex(where: { $0.name == group }) else {
            throw GroupCatalogError.groupNotFound(group)
        }

        guard !groups[index].subgroups.contains(subgroup) else {
            return
        }

        groups[index].subgroups.append(subgroup)
        groups[index].subgroups.sort()
    }
}

struct LegacySecretEntry: Equatable {
    let name: String
    let value: String
}

struct ScopedSecretKeyCodec {
    private static let prefix = "v1"

    func encode(_ reference: SecretReference) -> String {
        let subgroupValue = reference.scope.subgroup ?? ""
        let pieces = [
            Self.prefix,
            encodeComponent(reference.scope.group),
            encodeComponent(subgroupValue),
            encodeComponent(reference.name),
        ]

        return pieces.joined(separator: "|")
    }

    func decode(_ accountName: String) -> SecretReference? {
        let pieces = accountName.split(separator: "|", omittingEmptySubsequences: false).map(String.init)

        guard pieces.count == 4, pieces[0] == Self.prefix else {
            return nil
        }

        guard
            let group = decodeComponent(pieces[1]),
            let subgroupValue = decodeComponent(pieces[2]),
            let name = decodeComponent(pieces[3])
        else {
            return nil
        }

        let subgroup = subgroupValue.isEmpty ? nil : subgroupValue
        return try? SecretReference(scope: SecretScope(group: group, subgroup: subgroup), name: name)
    }

    private func encodeComponent(_ value: String) -> String {
        let data = Data(value.utf8)
        let base64 = data.base64EncodedString()

        return base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "~")
    }

    private func decodeComponent(_ value: String) -> String? {
        let normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "~", with: "=")

        guard let data = Data(base64Encoded: normalized) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
