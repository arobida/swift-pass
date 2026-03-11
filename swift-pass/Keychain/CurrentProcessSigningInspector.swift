import Foundation
import Security

struct CurrentProcessSigningStatus {
    let executablePath: String
    let applicationIdentifier: String?
    let keychainAccessGroups: [String]

    func hasExpectedKeychainEntitlements(for serviceName: String) -> Bool {
        guard let applicationIdentifier, matchesExpectedIdentifier(applicationIdentifier, serviceName: serviceName) else {
            return false
        }

        guard !keychainAccessGroups.isEmpty else {
            return true
        }

        return keychainAccessGroups.contains { matchesExpectedIdentifier($0, serviceName: serviceName) }
    }

    private func matchesExpectedIdentifier(_ value: String, serviceName: String) -> Bool {
        value == serviceName || value.hasSuffix(".\(serviceName)")
    }
}

enum CurrentProcessSigningInspectorError: LocalizedError {
    case copySelf(OSStatus)
    case copyStaticCode(OSStatus)
    case copySigningInformation(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .copySelf(status):
            return "Could not inspect the current executable signature (OSStatus \(status))."
        case let .copyStaticCode(status):
            return "Could not load the current executable's static code information (OSStatus \(status))."
        case let .copySigningInformation(status):
            return "Could not read the current executable entitlements (OSStatus \(status))."
        }
    }
}

struct CurrentProcessSigningInspector {
    func inspect() throws -> CurrentProcessSigningStatus {
        var currentCode: SecCode?
        let copySelfStatus = SecCodeCopySelf(SecCSFlags(), &currentCode)

        guard copySelfStatus == errSecSuccess, let currentCode else {
            throw CurrentProcessSigningInspectorError.copySelf(copySelfStatus)
        }

        var staticCode: SecStaticCode?
        let copyStaticCodeStatus = SecCodeCopyStaticCode(currentCode, SecCSFlags(), &staticCode)

        guard copyStaticCodeStatus == errSecSuccess, let staticCode else {
            throw CurrentProcessSigningInspectorError.copyStaticCode(copyStaticCodeStatus)
        }

        var signingInformation: CFDictionary?
        let copySigningInformationStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInformation
        )

        guard copySigningInformationStatus == errSecSuccess, let signingInformation else {
            throw CurrentProcessSigningInspectorError.copySigningInformation(copySigningInformationStatus)
        }

        let signingInformationDictionary = signingInformation as NSDictionary
        let entitlements = signingInformationDictionary[kSecCodeInfoEntitlementsDict as String] as? NSDictionary
        let applicationIdentifier =
            entitlements?["application-identifier"] as? String ??
            entitlements?["com.apple.application-identifier"] as? String
        let keychainAccessGroups = entitlements?["keychain-access-groups"] as? [String] ?? []

        return CurrentProcessSigningStatus(
            executablePath: URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.path,
            applicationIdentifier: applicationIdentifier,
            keychainAccessGroups: keychainAccessGroups
        )
    }
}
