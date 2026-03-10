import Foundation
import Security
import Valet

struct ValetSecretStore: SecretStore {
    let configuration: KeychainConfiguration

    private let valet: Valet

    init(configuration: KeychainConfiguration = .default) {
        self.configuration = configuration
        valet = Valet.valet(
            with: configuration.valetIdentifier,
            accessibility: configuration.accessibility
        )
    }

    func canAccessKeychain() -> Bool {
        valet.canAccessKeychain()
    }

    func setSecret(_ value: String, named name: String) throws -> SecretStoreSaveResult {
        guard let data = value.data(using: .utf8) else {
            throw SecretStoreError.invalidSecretEncoding(name)
        }

        let addStatus = SecItemAdd(addQuery(for: name, data: data) as CFDictionary, nil)

        switch addStatus {
        case errSecSuccess:
            return .created
        case errSecDuplicateItem:
            let updateStatus = SecItemUpdate(
                itemQuery(for: name) as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )

            guard updateStatus == errSecSuccess else {
                throw SecretStoreError.operationFailed(
                    operation: "update the secret named '\(name)' in the macOS Keychain",
                    status: updateStatus
                )
            }

            return .updated
        default:
            throw SecretStoreError.operationFailed(
                operation: "store the secret named '\(name)' in the macOS Keychain",
                status: addStatus
            )
        }
    }

    func secret(named name: String) throws -> String {
        var result: CFTypeRef?
        let query: [String: Any] = itemQuery(for: name).merging(
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
                throw SecretStoreError.invalidSecretData(name)
            }

            guard let secret = String(data: data, encoding: .utf8) else {
                throw SecretStoreError.invalidSecretData(name)
            }

            return secret
        case errSecItemNotFound:
            throw SecretStoreError.secretNotFound(name)
        default:
            throw SecretStoreError.operationFailed(
                operation: "read the secret named '\(name)' from the macOS Keychain",
                status: status
            )
        }
    }

    func removeSecret(named name: String) throws -> Bool {
        let status = SecItemDelete(itemQuery(for: name) as CFDictionary)

        switch status {
        case errSecSuccess:
            return true
        case errSecItemNotFound:
            return false
        default:
            throw SecretStoreError.operationFailed(
                operation: "delete the secret named '\(name)' from the macOS Keychain",
                status: status
            )
        }
    }

    func secretNames() throws -> [String] {
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
            return try secretNames(from: result).sorted()
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

    private func secretNames(from result: CFTypeRef?) throws -> [String] {
        if let items = result as? [[String: Any]] {
            return items.compactMap { $0[kSecAttrAccount as String] as? String }
        }

        if let item = result as? [String: Any] {
            if let name = item[kSecAttrAccount as String] as? String {
                return [name]
            }

            return []
        }

        throw SecretStoreError.operationFailed(
            operation: "decode the macOS Keychain item list",
            status: errSecInternalError
        )
    }
}
