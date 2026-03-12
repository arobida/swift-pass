import Security

struct KeychainConfiguration {
    static let `default` = Self(
        serviceName: "dev.keys.swift-pass",
        securityAccessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    )

    static let metadata = Self(
        serviceName: "dev.keys.swift-pass.metadata",
        securityAccessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    )

    let serviceName: String
    let securityAccessibility: CFString
}

extension Dictionary where Key == String, Value == Any {
    func mergeOverwriting(_ other: [String: Any]) -> [String: Any] {
        merging(other) { _, new in new }
    }
}

struct KeychainQueryBuilder {
    let serviceName: String

    func serviceQuery(accountName: String? = nil) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
        ]
        if let accountName {
            query[kSecAttrAccount as String] = accountName
        }
        return query
    }
}
