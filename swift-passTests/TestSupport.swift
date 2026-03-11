import Foundation
import XCTest
@testable import swift_passCore

final class StubPrompter: UserPrompter {
    var textInputs: [String]
    var confirmations: [Bool]

    init(textInputs: [String] = [], confirmations: [Bool] = []) {
        self.textInputs = textInputs
        self.confirmations = confirmations
    }

    func textInput(
        title: String,
        prompt: String,
        description: String?,
        defaultValue: String?
    ) -> String {
        if !textInputs.isEmpty {
            return textInputs.removeFirst()
        }

        return defaultValue ?? ""
    }

    func confirm(
        title: String?,
        question: String,
        defaultAnswer: Bool,
        description: String?
    ) -> Bool {
        if !confirmations.isEmpty {
            return confirmations.removeFirst()
        }

        return defaultAnswer
    }
}

final class InMemorySecretStore: SecretStore {
    var scopedValues: [SecretReference: String] = [:]
    var legacyValues: [String: String] = [:]
    var failWritesForNames: Set<String> = []

    func canAccessKeychain() -> Bool {
        true
    }

    func setSecret(_ value: String, at reference: SecretReference) throws -> SecretStoreSaveResult {
        if failWritesForNames.contains(reference.name) {
            throw SecretStoreError.operationFailed(
                operation: "store the secret named '\(reference.displayPath)' in the macOS Keychain",
                status: errSecInternalError
            )
        }

        let existed = scopedValues.updateValue(value, forKey: reference) != nil
        return existed ? .updated : .created
    }

    func secret(at reference: SecretReference) throws -> String {
        guard let value = scopedValues[reference] else {
            throw SecretStoreError.secretNotFound(reference.displayPath)
        }

        return value
    }

    func removeSecret(at reference: SecretReference) throws -> Bool {
        scopedValues.removeValue(forKey: reference) != nil
    }

    func secretNames(in scope: SecretScope) throws -> [String] {
        scopedValues.keys
            .filter { $0.scope == scope }
            .map(\.name)
            .sorted()
    }

    func legacySecretEntries() throws -> [LegacySecretEntry] {
        legacyValues
            .map { LegacySecretEntry(name: $0.key, value: $0.value) }
            .sorted { $0.name < $1.name }
    }

    func removeLegacySecret(named name: String) throws -> Bool {
        legacyValues.removeValue(forKey: name) != nil
    }
}

final class InMemoryGroupCatalogStore: GroupCatalogStore {
    var catalogValue: GroupCatalog?

    init(catalog: GroupCatalog? = nil) {
        catalogValue = catalog
    }

    func canAccessKeychain() -> Bool {
        true
    }

    func catalog() throws -> GroupCatalog? {
        catalogValue
    }

    func saveCatalog(_ catalog: GroupCatalog) throws {
        catalogValue = try catalog.validated()
    }
}
