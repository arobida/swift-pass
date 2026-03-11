struct CreateScopeOutcome {
    let created: Bool
    let scope: SecretScope
}

struct SecretVault {
    let secretStore: SecretStore
    let catalogStore: GroupCatalogStore
    let prompter: UserPrompter
    let environment: CLIEnvironment

    init(
        secretStore: SecretStore = ValetSecretStore(),
        catalogStore: GroupCatalogStore = KeychainGroupCatalogStore(),
        prompter: UserPrompter = NooraPrompter(),
        environment: CLIEnvironment = .live
    ) {
        self.secretStore = secretStore
        self.catalogStore = catalogStore
        self.prompter = prompter
        self.environment = environment
    }

    func canAccessSecretStore() -> Bool {
        secretStore.canAccessKeychain()
    }

    func canAccessCatalogStore() -> Bool {
        catalogStore.canAccessKeychain()
    }

    func currentCatalog() throws -> GroupCatalog? {
        try catalogStore.catalog()
    }

    func resolveScope(_ input: SecretScopeInput, forWrite: Bool) throws -> SecretScope {
        if let group = input.group {
            return try SecretScope(group: group, subgroup: input.subgroup)
        }

        guard input.subgroup == nil else {
            throw GroupCatalogError.invalidIdentifier(kind: "subgroup", value: input.subgroup ?? "")
        }

        let catalog = try catalogStore.catalog()

        if let catalog {
            return try SecretScope(group: catalog.defaultGroup)
        }

        guard forWrite else {
            throw GroupCatalogError.defaultGroupNotConfigured
        }

        return .defaultScope
    }

    @discardableResult
    func createScope(_ scope: SecretScope) throws -> CreateScopeOutcome {
        var catalog = try catalogForWrite()

        if let subgroup = scope.subgroup {
            if !catalog.containsGroup(scope.group) {
                guard environment.isInteractive else {
                    throw GroupCatalogError.nonInteractiveScopeCreationRequired(scope)
                }

                let createParent = prompter.confirm(
                    title: "Create parent group",
                    question: "Group '\(scope.group)' does not exist. Create it and subgroup '\(subgroup)'?",
                    defaultAnswer: true,
                    description: "The subgroup can only be created after its parent group exists."
                )

                guard createParent else {
                    throw GroupCatalogError.operationCancelled(
                        "Cancelled creating subgroup '\(subgroup)' because parent group '\(scope.group)' was not created."
                    )
                }

                catalog.addGroup(scope.group)
            }

            let existed = catalog.containsSubgroup(subgroup, in: scope.group)

            if !existed {
                try catalog.addSubgroup(subgroup, to: scope.group)
                try catalogStore.saveCatalog(catalog)
            }

            return CreateScopeOutcome(created: !existed, scope: scope)
        }

        let existed = catalog.containsGroup(scope.group)

        if !existed {
            catalog.addGroup(scope.group)
            try catalogStore.saveCatalog(catalog)
        }

        return CreateScopeOutcome(created: !existed, scope: scope)
    }

    func setSecret(_ value: String, at reference: SecretReference) throws -> SecretStoreSaveResult {
        try ensureScopeExistsForWrite(reference.scope)
        return try secretStore.setSecret(value, at: reference)
    }

    func secret(at reference: SecretReference) throws -> String {
        let catalog = try loadCatalogForRead()
        try ensureScopeExists(reference.scope, in: catalog)
        return try secretStore.secret(at: reference)
    }

    func removeSecret(at reference: SecretReference) throws -> Bool {
        let catalog = try loadCatalogForRead()
        try ensureScopeExists(reference.scope, in: catalog)
        return try secretStore.removeSecret(at: reference)
    }

    func secretNames(in scope: SecretScope) throws -> [String] {
        let catalog = try loadCatalogForRead()
        try ensureScopeExists(scope, in: catalog)
        return try secretStore.secretNames(in: scope)
    }

    private func ensureScopeExistsForWrite(_ scope: SecretScope) throws {
        var catalog = try catalogForWrite()

        if catalog.scopeExists(scope) {
            return
        }

        guard environment.isInteractive else {
            throw GroupCatalogError.nonInteractiveScopeCreationRequired(scope)
        }

        let question: String
        let description: String

        if let subgroup = scope.subgroup {
            if !catalog.containsGroup(scope.group) {
                question = "Scope '\(scope.displayPath)' does not exist. Create group '\(scope.group)' and subgroup '\(subgroup)'?"
                description = "The secret can only be stored after both the parent group and subgroup exist."
            } else {
                question = "Subgroup '\(subgroup)' does not exist in group '\(scope.group)'. Create it?"
                description = "The secret will be stored in the new subgroup."
            }
        } else {
            question = "Group '\(scope.group)' does not exist. Create it?"
            description = "The secret will be stored in the new group."
        }

        let shouldCreate = prompter.confirm(
            title: "Create missing scope",
            question: question,
            defaultAnswer: true,
            description: description
        )

        guard shouldCreate else {
            throw GroupCatalogError.operationCancelled(
                "Cancelled storing the secret because the \(scope.locationDescription) scope was not created."
            )
        }

        if !catalog.containsGroup(scope.group) {
            catalog.addGroup(scope.group)
        }

        if let subgroup = scope.subgroup {
            try catalog.addSubgroup(subgroup, to: scope.group)
        }

        try catalogStore.saveCatalog(catalog)
    }

    private func loadCatalogForRead() throws -> GroupCatalog {
        guard let catalog = try catalogStore.catalog() else {
            throw GroupCatalogError.defaultGroupNotConfigured
        }

        return catalog
    }

    private func catalogForWrite() throws -> GroupCatalog {
        if let catalog = try catalogStore.catalog() {
            return catalog
        }

        return try bootstrapCatalog()
    }

    private func bootstrapCatalog() throws -> GroupCatalog {
        var catalog = GroupCatalog.bootstrappedDefault()
        let defaultScope = try SecretScope(group: catalog.defaultGroup)
        let legacyEntries = try secretStore.legacySecretEntries()

        for entry in legacyEntries {
            let reference = try SecretReference(scope: defaultScope, name: entry.name)
            _ = try secretStore.setSecret(entry.value, at: reference)

            let storedValue = try secretStore.secret(at: reference)

            guard storedValue == entry.value else {
                throw GroupCatalogError.catalogCorrupted("legacy secret '\(entry.name)' did not verify after migration")
            }

            _ = try secretStore.removeLegacySecret(named: entry.name)
        }

        try catalogStore.saveCatalog(catalog)
        return catalog
    }

    private func ensureScopeExists(_ scope: SecretScope, in catalog: GroupCatalog) throws {
        if let subgroup = scope.subgroup {
            guard catalog.containsGroup(scope.group) else {
                throw GroupCatalogError.groupNotFound(scope.group)
            }

            guard catalog.containsSubgroup(subgroup, in: scope.group) else {
                throw GroupCatalogError.subgroupNotFound(group: scope.group, subgroup: subgroup)
            }

            return
        }

        guard catalog.containsGroup(scope.group) else {
            throw GroupCatalogError.groupNotFound(scope.group)
        }
    }
}
