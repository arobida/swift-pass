import Foundation
import Security

struct KeychainAccessProbe {
    private static let probeValue = Data("swift-pass-keychain-probe".utf8)

    let serviceName: String
    let accessibility: CFString
    let accountPrefix: String

    func canAccess() -> Bool {
        let accountName = "\(accountPrefix).\(UUID().uuidString)"
        let itemQuery = serviceQuery(accountName: accountName)
        let addQuery = itemQuery.merging(
            [
                kSecAttrAccessible as String: accessibility,
                kSecValueData as String: Self.probeValue,
            ]
        ) { _, newValue in
            newValue
        }

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        guard addStatus == errSecSuccess else {
            return false
        }

        defer {
            _ = SecItemDelete(itemQuery as CFDictionary)
        }

        var result: CFTypeRef?
        let readQuery = itemQuery.merging(
            [
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecReturnData as String: true,
            ]
        ) { _, newValue in
            newValue
        }
        let readStatus = SecItemCopyMatching(readQuery as CFDictionary, &result)

        guard readStatus == errSecSuccess, let data = result as? Data else {
            return false
        }

        return data == Self.probeValue
    }

    private func serviceQuery(accountName: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
        ]
    }
}
