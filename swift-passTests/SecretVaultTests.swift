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

    func testListEntriesIncludeStructuredMetadataForScope() throws {
        let secretStore = InMemorySecretStore()
        let catalogStore = InMemoryGroupCatalogStore(
            catalog: GroupCatalog(
                schemaVersion: GroupCatalog.currentSchemaVersion,
                defaultGroup: "default",
                groups: [
                    .init(name: "default", subgroups: ["dev"]),
                ]
            )
        )
        let vault = SecretVault(
            secretStore: secretStore,
            catalogStore: catalogStore,
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )
        let scope = try SecretScope(group: "default", subgroup: "dev")
        let date = Date(timeIntervalSince1970: 1_736_082_000)
        let reference = try SecretReference(scope: scope, name: "github")
        secretStore.scopedValues[reference] = "token"
        secretStore.scopedModificationDates[reference] = date

        let entries = try vault.secretListEntries(in: scope)

        XCTAssertEqual(
            entries,
            [SecretListEntry(reference: reference, modificationDate: date)]
        )
    }

    func testGroupListEntriesReturnsEmptyArrayWhenCatalogIsMissing() throws {
        let vault = SecretVault(
            secretStore: InMemorySecretStore(),
            catalogStore: InMemoryGroupCatalogStore(),
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )

        XCTAssertEqual(try vault.groupListEntries(), [])
    }

    func testGroupListEntriesIncludeSubgroupsAndDirectSecretCount() throws {
        let secretStore = InMemorySecretStore()
        let vault = SecretVault(
            secretStore: secretStore,
            catalogStore: InMemoryGroupCatalogStore(
                catalog: GroupCatalog(
                    schemaVersion: GroupCatalog.currentSchemaVersion,
                    defaultGroup: "default",
                    groups: [
                        .init(name: "default", subgroups: []),
                        .init(name: "project", subgroups: ["dev", "prod"]),
                    ]
                )
            ),
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )
        secretStore.scopedValues[try SecretReference(scope: SecretScope(group: "project"), name: "github")] = "token"
        secretStore.scopedValues[try SecretReference(scope: SecretScope(group: "project", subgroup: "dev"), name: "openai")] = "token"

        let entries = try vault.groupListEntries()

        XCTAssertEqual(
            entries,
            [
                GroupListEntry(
                    group: "default",
                    subgroups: [],
                    secretCount: 0
                ),
                GroupListEntry(
                    group: "project",
                    subgroups: ["dev", "prod"],
                    secretCount: 1
                ),
            ]
        )
    }

    func testSubgroupListEntriesShowOnlySubgroupsForRequestedGroup() throws {
        let secretStore = InMemorySecretStore()
        let vault = SecretVault(
            secretStore: secretStore,
            catalogStore: InMemoryGroupCatalogStore(
                catalog: GroupCatalog(
                    schemaVersion: GroupCatalog.currentSchemaVersion,
                    defaultGroup: "default",
                    groups: [
                        .init(name: "default", subgroups: []),
                        .init(name: "project", subgroups: ["dev", "prod"]),
                    ]
                )
            ),
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )
        secretStore.scopedValues[try SecretReference(scope: SecretScope(group: "project", subgroup: "dev"), name: "openai")] = "token"
        secretStore.scopedValues[try SecretReference(scope: SecretScope(group: "project", subgroup: "prod"), name: "github")] = "token"
        secretStore.scopedValues[try SecretReference(scope: SecretScope(group: "project"), name: "group-only")] = "token"

        let entries = try vault.subgroupListEntries(in: "project")

        XCTAssertEqual(
            entries,
            [
                SubgroupListEntry(
                    scope: try SecretScope(group: "project", subgroup: "dev"),
                    secretCount: 1
                ),
                SubgroupListEntry(
                    scope: try SecretScope(group: "project", subgroup: "prod"),
                    secretCount: 1
                ),
            ]
        )
    }

    func testSubgroupListEntriesThrowWhenGroupDoesNotExist() {
        let vault = SecretVault(
            secretStore: InMemorySecretStore(),
            catalogStore: InMemoryGroupCatalogStore(catalog: GroupCatalog.bootstrappedDefault()),
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )

        XCTAssertThrowsError(try vault.subgroupListEntries(in: "missing")) { error in
            XCTAssertEqual(error.localizedDescription, GroupCatalogError.groupNotFound("missing").localizedDescription)
        }
    }

    func testResolveScopeUsesConfiguredDefaultGroupWhenListGroupIsOmitted() throws {
        let vault = SecretVault(
            secretStore: InMemorySecretStore(),
            catalogStore: InMemoryGroupCatalogStore(
                catalog: GroupCatalog(
                    schemaVersion: GroupCatalog.currentSchemaVersion,
                    defaultGroup: "team",
                    groups: [
                        .init(name: "default", subgroups: []),
                        .init(name: "team", subgroups: []),
                    ]
                )
            ),
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )

        let scope = try vault.resolveScope(SecretScopeInput(), forWrite: false)

        XCTAssertEqual(scope, try SecretScope(group: "team"))
    }

    func testDoctorStatusReportsHealthyCatalogAndNoOrphanedSecrets() throws {
        let secretStore = InMemorySecretStore()
        let catalog = GroupCatalog(
            schemaVersion: GroupCatalog.currentSchemaVersion,
            defaultGroup: "default",
            groups: [
                .init(name: "default", subgroups: []),
                .init(name: "project", subgroups: ["dev"]),
            ]
        )
        let catalogStore = InMemoryGroupCatalogStore(catalog: catalog)
        let vault = SecretVault(
            secretStore: secretStore,
            catalogStore: catalogStore,
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )
        secretStore.scopedValues[try SecretReference(scope: SecretScope(group: "default"), name: "github")] = "token"
        secretStore.scopedValues[try SecretReference(scope: SecretScope(group: "project", subgroup: "dev"), name: "openai")] = "token"

        let status = try vault.doctorStatus()

        XCTAssertEqual(status.catalog, catalog)
        XCTAssertEqual(status.orphanedSecretReferences, [])
        XCTAssertEqual(status.legacySecretEntries, [])
    }

    func testDoctorStatusTreatsAllScopedSecretsAsOrphanedWhenCatalogIsMissing() throws {
        let secretStore = InMemorySecretStore()
        let vault = SecretVault(
            secretStore: secretStore,
            catalogStore: InMemoryGroupCatalogStore(),
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )
        let reference = try SecretReference(scope: SecretScope(group: "default"), name: "github")
        secretStore.scopedValues[reference] = "token"

        let status = try vault.doctorStatus()

        XCTAssertNil(status.catalog)
        XCTAssertEqual(status.orphanedSecretReferences, [reference])
    }

    func testDoctorStatusReportsSecretsWhoseParentScopeIsMissingFromCatalog() throws {
        let secretStore = InMemorySecretStore()
        let catalogStore = InMemoryGroupCatalogStore(
            catalog: GroupCatalog(
                schemaVersion: GroupCatalog.currentSchemaVersion,
                defaultGroup: "default",
                groups: [
                    .init(name: "default", subgroups: []),
                    .init(name: "project", subgroups: []),
                ]
            )
        )
        let vault = SecretVault(
            secretStore: secretStore,
            catalogStore: catalogStore,
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )
        let missingGroupReference = try SecretReference(scope: SecretScope(group: "orphaned"), name: "github")
        let missingSubgroupReference = try SecretReference(scope: SecretScope(group: "project", subgroup: "dev"), name: "openai")
        secretStore.scopedValues[missingGroupReference] = "token"
        secretStore.scopedValues[missingSubgroupReference] = "token"

        let status = try vault.doctorStatus()

        XCTAssertEqual(status.orphanedSecretReferences, [missingGroupReference, missingSubgroupReference])
    }

    func testDoctorStatusIncludesLegacySecretsWithoutParentGroup() throws {
        let secretStore = InMemorySecretStore()
        secretStore.legacyValues["github"] = "legacy-token"
        let vault = SecretVault(
            secretStore: secretStore,
            catalogStore: InMemoryGroupCatalogStore(catalog: GroupCatalog.bootstrappedDefault()),
            prompter: StubPrompter(),
            environment: .init(isInteractive: true)
        )

        let status = try vault.doctorStatus()

        XCTAssertEqual(status.legacySecretEntries, [LegacySecretEntry(name: "github", value: "legacy-token")])
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
