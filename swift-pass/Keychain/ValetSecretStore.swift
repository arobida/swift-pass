import Foundation
import Security
import Valet

struct ValetSecretStore: SecretStore {
    let configuration: KeychainConfiguration

    private let codec: ScopedSecretKeyCodec
    private let valet: Valet

    private struct KeychainItemAttributes {
        let accountName: String
        let modificationDate: Date?
    }

    init(configuration: KeychainConfiguration = .default) {
        self.configuration = configuration
        codec = ScopedSecretKeyCodec()
        valet = Valet.valet(
            with: configuration.valetIdentifier,
            accessibility: configuration.accessibility
        )
    }

    func canAccessKeychain() -> Bool {
        valet.canAccessKeychain()
    }

    func setSecret(_ value: String, at reference: SecretReference) throws -> SecretStoreSaveResult {
        try setSecret(value, accountName: codec.encode(reference), label: reference.displayPath)
    }

    func secret(at reference: SecretReference) throws -> String {
        try secretValue(accountName: codec.encode(reference), label: reference.displayPath)
    }

    func removeSecret(at reference: SecretReference) throws -> Bool {
        try removeSecret(accountName: codec.encode(reference), label: reference.displayPath)
    }

    func allSecretReferences() throws -> [SecretReference] {
        try allItemAttributes()
            .compactMap { attributes in
                codec.decode(attributes.accountName)
            }
            .sorted { $0.displayPath < $1.displayPath }
    }

    func secretListEntries(in scope: SecretScope) throws -> [SecretListEntry] {
        try allItemAttributes()
            .compactMap { attributes in
                guard let reference = codec.decode(attributes.accountName), reference.scope == scope else {
                    return nil
                }

                return SecretListEntry(
                    reference: reference,
                    modificationDate: attributes.modificationDate
                )
            }
            .sorted { $0.reference.name < $1.reference.name }
    }

    func secretNames(in scope: SecretScope) throws -> [String] {
        try secretListEntries(in: scope).map(\.reference.name)
    }

    func legacySecretEntries() throws -> [LegacySecretEntry] {
        try allItemAttributes()
            .map(\.accountName)
            .filter { codec.decode($0) == nil }
            .sorted()
            .map { LegacySecretEntry(name: $0, value: try secretValue(accountName: $0, label: $0)) }
    }

    func removeLegacySecret(named name: String) throws -> Bool {
        try removeSecret(accountName: name, label: name)
    }

    private func setSecret(_ value: String, accountName: String, label: String) throws -> SecretStoreSaveResult {
        guard let data = value.data(using: .utf8) else {
            throw SecretStoreError.invalidSecretEncoding(label)
        }

        let addStatus = SecItemAdd(addQuery(for: accountName, data: data) as CFDictionary, nil)

        switch addStatus {
        case errSecSuccess:
            return .created
        case errSecDuplicateItem:
            let updateStatus = SecItemUpdate(
                itemQuery(for: accountName) as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )

            guard updateStatus == errSecSuccess else {
                throw SecretStoreError.operationFailed(
                    operation: "update the secret named '\(label)' in the macOS Keychain",
                    status: updateStatus
                )
            }

            return .updated
        default:
            throw SecretStoreError.operationFailed(
                operation: "store the secret named '\(label)' in the macOS Keychain",
                status: addStatus
            )
        }
    }

    private func secretValue(accountName: String, label: String) throws -> String {
        var result: CFTypeRef?
        let query: [String: Any] = itemQuery(for: accountName).merging(
            [
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecReturnData as String: true,
            ]
        ) { _, newValue in
            newValue
        }
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw SecretStoreError.invalidSecretData(label)
            }

            guard let secret = String(data: data, encoding: .utf8) else {
                throw SecretStoreError.invalidSecretData(label)
            }

            return secret
        case errSecItemNotFound:
            throw SecretStoreError.secretNotFound(label)
        default:
            throw SecretStoreError.operationFailed(
                operation: "read the secret named '\(label)' from the macOS Keychain",
                status: status
            )
        }
    }

    private func removeSecret(accountName: String, label: String) throws -> Bool {
        let status = SecItemDelete(itemQuery(for: accountName) as CFDictionary)

        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            throw SecretStoreError.operationFailed(
                operation: "delete the secret named '\(label)' from the macOS Keychain",
                status: status
            )
        }
    }

    private func allItemAttributes() throws -> [KeychainItemAttributes] {
        var result: CFTypeRef?
        let query: [String: Any] = serviceQuery().merging(
            [
                kSecMatchLimit as String: kSecMatchLimitAll,
                kSecReturnAttributes as String: true,
            ]
        ) { _, newValue in
            newValue
        }
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return try itemAttributes(from: result)
        case errSecItemNotFound:
            return []
        default:
            throw SecretStoreError.operationFailed(
                operation: "list secrets from the macOS Keychain",
                status: status
            )
        }
    }

    private func serviceQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: configuration.serviceName,
        ]
    }

    private func itemQuery(for name: String) -> [String: Any] {
        serviceQuery().merging([kSecAttrAccount as String: name]) { _, newValue in
            newValue
        }
    }

    private func addQuery(for name: String, data: Data) -> [String: Any] {
        itemQuery(for: name).merging(
            [
                kSecAttrAccessible as String: configuration.securityAccessibility,
                kSecValueData as String: data,
            ]
        ) { _, newValue in
            newValue
        }
    }

    private func itemAttributes(from result: CFTypeRef?) throws -> [KeychainItemAttributes] {
        if let items = result as? [[String: Any]] {
            return items.compactMap(keychainItemAttributes(from:))
        }

        if let item = result as? [String: Any] {
            if let attributes = keychainItemAttributes(from: item) {
                return [attributes]
            }

            return []
        }

        throw SecretStoreError.operationFailed(
            operation: "decode the macOS Keychain item list",
            status: errSecInternalError
        )
    }

    private func keychainItemAttributes(from item: [String: Any]) -> KeychainItemAttributes? {
        guard let accountName = item[kSecAttrAccount as String] as? String else {
            return nil
        }

        return KeychainItemAttributes(
            accountName: accountName,
            modificationDate: item[kSecAttrModificationDate as String] as? Date
        )
    }
}
