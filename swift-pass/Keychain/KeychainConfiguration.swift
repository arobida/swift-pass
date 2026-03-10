import Security
import Valet

struct KeychainConfiguration {
    static let `default` = Self(
        serviceName: "dev.arobida.swift-pass",
        accessibility: .whenUnlockedThisDeviceOnly,
        securityAccessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    )

    let serviceName: String
    let accessibility: Accessibility
    let securityAccessibility: CFString

    var valetIdentifier: Identifier {
        guard let identifier = Identifier(nonEmpty: serviceName) else {
            preconditionFailure("Keychain service name must not be empty.")
        }

        return identifier
    }
}
