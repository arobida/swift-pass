import Foundation
import Security

struct KeychainGroupCatalogStore: GroupCatalogStore {
    let configuration: KeychainConfiguration

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let accountName = "group-catalog"

    init(configuration: KeychainConfiguration = .metadata) {
        self.configuration = configuration
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func canAccessKeychain() -> Bool {
        KeychainAccessProbe(
            serviceName: configuration.serviceName,
            accessibility: configuration.securityAccessibility,
            accountPrefix: "swift-pass.catalog-store.probe"
        ).canAccess()
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

    private var queryBuilder: KeychainQueryBuilder {
        KeychainQueryBuilder(serviceName: configuration.serviceName)
    }

    private func serviceQuery() -> [String: Any] {
        queryBuilder.serviceQuery(accountName: accountName)
    }

    private func query(returnData: Bool) -> [String: Any] {
        guard returnData else {
            return serviceQuery()
        }

        return serviceQuery().mergeOverwriting([
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ])
    }

    private func addQuery(data: Data) -> [String: Any] {
        serviceQuery().mergeOverwriting([
            kSecAttrAccessible as String: configuration.securityAccessibility,
            kSecValueData as String: data,
        ])
    }
}
