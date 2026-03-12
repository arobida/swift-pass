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
    var scopedModificationDates: [SecretReference: Date] = [:]

    func canAccessKeychain() -> Bool {
        true
    }

    func setSecret(_ value: String, at reference: SecretReference) throws -> SecretStoreSaveResult {
        let existed = scopedValues.updateValue(value, forKey: reference) != nil
        scopedModificationDates[reference] = scopedModificationDates[reference] ?? Date(timeIntervalSince1970: 0)
        return existed ? .updated : .created
    }

    func secret(at reference: SecretReference) throws -> String {
        guard let value = scopedValues[reference] else {
            throw SecretStoreError.secretNotFound(reference.displayPath)
        }

        return value
    }

    func removeSecret(at reference: SecretReference) throws -> Bool {
        scopedModificationDates.removeValue(forKey: reference)
        return scopedValues.removeValue(forKey: reference) != nil
    }

    func allSecretReferences() throws -> [SecretReference] {
        scopedValues.keys.sorted { $0.displayPath < $1.displayPath }
    }

    func secretListEntries(in scope: SecretScope) throws -> [SecretListEntry] {
        scopedValues.keys
            .filter { $0.scope == scope }
            .map { reference in
                SecretListEntry(
                    reference: reference,
                    modificationDate: scopedModificationDates[reference]
                )
            }
            .sorted { $0.reference.name < $1.reference.name }
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
