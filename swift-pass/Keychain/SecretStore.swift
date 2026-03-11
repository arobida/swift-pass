enum SecretStoreSaveResult {
    case created
    case updated
}

protocol SecretStore {
    func canAccessKeychain() -> Bool
    func setSecret(_ value: String, at reference: SecretReference) throws -> SecretStoreSaveResult
    func secret(at reference: SecretReference) throws -> String
    func removeSecret(at reference: SecretReference) throws -> Bool
    func allSecretReferences() throws -> [SecretReference]
    func secretListEntries(in scope: SecretScope) throws -> [SecretListEntry]
    func secretNames(in scope: SecretScope) throws -> [String]
    func legacySecretEntries() throws -> [LegacySecretEntry]
    func removeLegacySecret(named name: String) throws -> Bool
}
