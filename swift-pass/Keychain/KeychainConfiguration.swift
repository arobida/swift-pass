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
