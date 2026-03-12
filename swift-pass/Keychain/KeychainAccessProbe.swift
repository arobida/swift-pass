import Foundation
import Security

struct KeychainAccessProbe {
    private static let probeValue = Data("swift-pass-keychain-probe".utf8)

    let serviceName: String
    let accessibility: CFString
    let accountPrefix: String

    func canAccess() -> Bool {
        let accountName = "\(accountPrefix).\(UUID().uuidString)"
        let builder = KeychainQueryBuilder(serviceName: serviceName)
        let itemQuery = builder.serviceQuery(accountName: accountName)
        let addQuery = itemQuery.mergeOverwriting([
            kSecAttrAccessible as String: accessibility,
            kSecValueData as String: Self.probeValue,
        ])

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        guard addStatus == errSecSuccess else {
            return false
        }

        defer {
            _ = SecItemDelete(itemQuery as CFDictionary)
        }

        var result: CFTypeRef?
        let readQuery = itemQuery.mergeOverwriting([
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ])
        let readStatus = SecItemCopyMatching(readQuery as CFDictionary, &result)

        guard readStatus == errSecSuccess, let data = result as? Data else {
            return false
        }

        return data == Self.probeValue
    }
}
