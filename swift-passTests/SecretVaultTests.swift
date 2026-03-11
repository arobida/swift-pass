import XCTest
@testable import swift_passCore

final class SecretVaultTests: XCTestCase {
    func testFirstSetBootstrapsDefaultCatalogAndMigratesLegacySecrets() throws {
        let secretStore = InMemorySecretStore()
        secretStore.legacyValues["github"] = "legacy-token"
        let catalogStore = InMemoryGroupCatalogStore()
        let vault = SecretVault(
            secretStore: secretStore,
            catalogStore: catalogStore,
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )

        let defaultScope = try vault.resolveScope(SecretScopeInput(), forWrite: true)
        let newReference = try SecretReference(scope: defaultScope, name: "openai")
        _ = try vault.setSecret("new-token", at: newReference)

        XCTAssertEqual(catalogStore.catalogValue?.defaultGroup, "default")
        XCTAssertTrue(catalogStore.catalogValue?.containsGroup("default") == true)
        XCTAssertTrue(secretStore.legacyValues.isEmpty)
        XCTAssertEqual(secretStore.scopedValues[try SecretReference(scope: defaultScope, name: "github")], "legacy-token")
        XCTAssertEqual(secretStore.scopedValues[newReference], "new-token")
    }

    func testCreateGroupInitializesCatalogWhenMissing() throws {
        let catalogStore = InMemoryGroupCatalogStore()
        let vault = SecretVault(
            secretStore: InMemorySecretStore(),
            catalogStore: catalogStore,
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )

        let outcome = try vault.createScope(SecretScope(group: "myproject"))

        XCTAssertTrue(outcome.created)
        XCTAssertTrue(catalogStore.catalogValue?.containsGroup("default") == true)
        XCTAssertTrue(catalogStore.catalogValue?.containsGroup("myproject") == true)
    }

    func testReadWithoutCatalogFailsWhenDefaultGroupIsMissing() {
        let vault = SecretVault(
            secretStore: InMemorySecretStore(),
            catalogStore: InMemoryGroupCatalogStore(),
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )

        XCTAssertThrowsError(try vault.resolveScope(SecretScopeInput(), forWrite: false)) { error in
            XCTAssertEqual(error.localizedDescription, GroupCatalogError.defaultGroupNotConfigured.localizedDescription)
        }
    }

    func testListScopeExcludesSubgroupSecretsFromParentGroup() throws {
        let secretStore = InMemorySecretStore()
        let catalogStore = InMemoryGroupCatalogStore(
            catalog: GroupCatalog(
                schemaVersion: GroupCatalog.currentSchemaVersion,
                defaultGroup: "default",
                groups: [
                    .init(name: "default", subgroups: []),
                    .init(name: "myproject", subgroups: ["dev"]),
                ]
            )
        )
        let vault = SecretVault(
            secretStore: secretStore,
            catalogStore: catalogStore,
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )
        let groupReference = try SecretReference(scope: SecretScope(group: "myproject"), name: "github")
        let subgroupReference = try SecretReference(scope: SecretScope(group: "myproject", subgroup: "dev"), name: "github")
        secretStore.scopedValues[groupReference] = "group-token"
        secretStore.scopedValues[subgroupReference] = "subgroup-token"

        let names = try vault.secretNames(in: SecretScope(group: "myproject"))

        XCTAssertEqual(names, ["github"])
    }

    func testDuplicateCreateIsIdempotent() throws {
        let catalogStore = InMemoryGroupCatalogStore()
        let vault = SecretVault(
            secretStore: InMemorySecretStore(),
            catalogStore: catalogStore,
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )
        let scope = try SecretScope(group: "myproject")

        _ = try vault.createScope(scope)
        let second = try vault.createScope(scope)

        XCTAssertFalse(second.created)
    }

    func testSameSecretNameCanExistInDifferentScopes() throws {
        let secretStore = InMemorySecretStore()
        let catalogStore = InMemoryGroupCatalogStore(
            catalog: GroupCatalog(
                schemaVersion: GroupCatalog.currentSchemaVersion,
                defaultGroup: "default",
                groups: [
                    .init(name: "default", subgroups: []),
                    .init(name: "myproject", subgroups: []),
                ]
            )
        )
        let vault = SecretVault(
            secretStore: secretStore,
            catalogStore: catalogStore,
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )
        let defaultReference = try SecretReference(scope: SecretScope(group: "default"), name: "github")
        let projectReference = try SecretReference(scope: SecretScope(group: "myproject"), name: "github")

        _ = try vault.setSecret("default-token", at: defaultReference)
        _ = try vault.setSecret("project-token", at: projectReference)

        XCTAssertEqual(try vault.secret(at: defaultReference), "default-token")
        XCTAssertEqual(try vault.secret(at: projectReference), "project-token")
    }

    func testSetMissingGroupPromptsAndCreatesScope() throws {
        let catalogStore = InMemoryGroupCatalogStore(catalog: GroupCatalog.bootstrappedDefault())
        let secretStore = InMemorySecretStore()
        let vault = SecretVault(
            secretStore: secretStore,
            catalogStore: catalogStore,
            prompter: StubPrompter(confirmations: [true]),
            environment: .init(isInteractive: true)
        )
        let reference = try SecretReference(scope: SecretScope(group: "myproject"), name: "github")

        _ = try vault.setSecret("token", at: reference)

        XCTAssertTrue(catalogStore.catalogValue?.containsGroup("myproject") == true)
        XCTAssertEqual(secretStore.scopedValues[reference], "token")
    }

    func testSetAbortsWhenUserDeclinesCreatingMissingGroup() throws {
        let catalogStore = InMemoryGroupCatalogStore(catalog: GroupCatalog.bootstrappedDefault())
        let vault = SecretVault(
            secretStore: InMemorySecretStore(),
            catalogStore: catalogStore,
            prompter: StubPrompter(confirmations: [false]),
            environment: .init(isInteractive: true)
        )
        let reference = try SecretReference(scope: SecretScope(group: "myproject"), name: "github")

        XCTAssertThrowsError(try vault.setSecret("token", at: reference)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Cancelled storing the secret"))
        }
        XCTAssertFalse(catalogStore.catalogValue?.containsGroup("myproject") == true)
    }

    func testCreateSubgroupPromptsToCreateParentGroupFirst() throws {
        let catalogStore = InMemoryGroupCatalogStore(catalog: GroupCatalog.bootstrappedDefault())
        let vault = SecretVault(
            secretStore: InMemorySecretStore(),
            catalogStore: catalogStore,
            prompter: StubPrompter(confirmations: [true]),
            environment: .init(isInteractive: true)
        )

        let outcome = try vault.createScope(SecretScope(group: "myproject", subgroup: "dev"))

        XCTAssertTrue(outcome.created)
        XCTAssertTrue(catalogStore.catalogValue?.containsGroup("myproject") == true)
        XCTAssertTrue(catalogStore.catalogValue?.containsSubgroup("dev", in: "myproject") == true)
    }

    func testNonInteractiveMissingGroupWriteFails() throws {
        let catalogStore = InMemoryGroupCatalogStore(catalog: GroupCatalog.bootstrappedDefault())
        let vault = SecretVault(
            secretStore: InMemorySecretStore(),
            catalogStore: catalogStore,
            prompter: StubPrompter(),
            environment: .init(isInteractive: false)
        )
        let reference = try SecretReference(scope: SecretScope(group: "myproject"), name: "github")

        XCTAssertThrowsError(try vault.setSecret("token", at: reference)) { error in
            XCTAssertEqual(
                error.localizedDescription,
                GroupCatalogError.nonInteractiveScopeCreationRequired(try! SecretScope(group: "myproject")).localizedDescription
            )
        }
    }

    func testMigrationFailureLeavesCatalogUnsetAndLegacySecretIntact() throws {
        let secretStore = InMemorySecretStore()
        secretStore.legacyValues["github"] = "legacy-token"
        secretStore.failWritesForNames = ["github"]
        let catalogStore = InMemoryGroupCatalogStore()
        let vault = SecretVault(
            secretStore: secretStore,
            catalogStore: catalogStore,
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )
        let reference = try SecretReference(scope: SecretScope(group: "default"), name: "openai")

        XCTAssertThrowsError(try vault.setSecret("new-token", at: reference))
        XCTAssertNil(catalogStore.catalogValue)
        XCTAssertEqual(secretStore.legacyValues["github"], "legacy-token")
    }
}
