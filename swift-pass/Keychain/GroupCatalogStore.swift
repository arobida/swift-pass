protocol GroupCatalogStore {
    func canAccessKeychain() -> Bool
    func catalog() throws -> GroupCatalog?
    func saveCatalog(_ catalog: GroupCatalog) throws
}
