import Foundation
import Security
import Valet

struct KeychainGroupCatalogStore: GroupCatalogStore {
    let configuration: KeychainConfiguration

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let valet: Valet
    private let accountName = "group-catalog"

    init(configuration: KeychainConfiguration = .metadata) {
        self.configuration = configuration
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        valet = Valet.valet(
            with: configuration.valetIdentifier,
            accessibility: configuration.accessibility
        )
    }

    func canAccessKeychain() -> Bool {
        valet.canAccessKeychain()
    }

    func catalog() throws -> GroupCatalog? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query(returnData: true) as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw GroupCatalogError.catalogCorrupted("catalog data was not returned as Data")
            }

            do {
                return try decoder.decode(GroupCatalog.self, from: data).validated()
            } catch let error as GroupCatalogError {
                throw error
            } catch {
                throw GroupCatalogError.catalogCorrupted(error.localizedDescription)
            }
        case errSecItemNotFound:
            return nil
        default:
            throw SecretStoreError.operationFailed(
                operation: "read the group catalog from the macOS Keychain",
                status: status
            )
        }
    }

    func saveCatalog(_ catalog: GroupCatalog) throws {
        let validatedCatalog = try catalog.validated()
        let data = try encoder.encode(validatedCatalog)
        let addStatus = SecItemAdd(addQuery(data: data) as CFDictionary, nil)

        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let updateStatus = SecItemUpdate(
                query(returnData: false) as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )

            guard updateStatus == errSecSuccess else {
                throw SecretStoreError.operationFailed(
                    operation: "update the group catalog in the macOS Keychain",
                    status: updateStatus
                )
            }
        default:
            throw SecretStoreError.operationFailed(
                operation: "store the group catalog in the macOS Keychain",
                status: addStatus
            )
        }
    }

    private func serviceQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: configuration.serviceName,
            kSecAttrAccount as String: accountName,
        ]
    }

    private func query(returnData: Bool) -> [String: Any] {
        var query = serviceQuery()

        if returnData {
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            query[kSecReturnData as String] = true
        }

        return query
    }

    private func addQuery(data: Data) -> [String: Any] {
        serviceQuery().merging(
            [
                kSecAttrAccessible as String: configuration.securityAccessibility,
                kSecValueData as String: data,
            ]
        ) { _, newValue in
            newValue
        }
    }
}
