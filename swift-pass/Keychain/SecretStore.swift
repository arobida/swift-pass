enum SecretStoreSaveResult {
    case created
    case updated
}

protocol SecretStore {
    func canAccessKeychain() -> Bool
    func setSecret(_ value: String, named name: String) throws -> SecretStoreSaveResult
    func secret(named name: String) throws -> String
    func removeSecret(named name: String) throws -> Bool
    func secretNames() throws -> [String]
}
