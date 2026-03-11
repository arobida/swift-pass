import XCTest
@testable import swift_passCore

final class CommandInputResolverTests: XCTestCase {
    func testSetShorthandWithoutGroupUsesDefaultScopeInput() throws {
        let input = try CommandInputResolver.resolveSetInput(
            entry: "github=token-123",
            group: nil,
            subgroup: nil,
            name: nil,
            value: nil,
            prompter: StubPrompter()
        )

        XCTAssertEqual(input.scope, SecretScopeInput())
        XCTAssertEqual(input.name, "github")
        XCTAssertEqual(input.value, "token-123")
    }

    func testSetShorthandWithGroupAndSubgroupParsesAllComponents() throws {
        let input = try CommandInputResolver.resolveSetInput(
            entry: "myproject:dev:github=token-123",
            group: nil,
            subgroup: nil,
            name: nil,
            value: nil,
            prompter: StubPrompter()
        )

        XCTAssertEqual(input.scope, SecretScopeInput(group: "myproject", subgroup: "dev"))
        XCTAssertEqual(input.name, "github")
        XCTAssertEqual(input.value, "token-123")
    }

    func testExplicitSubgroupRequiresGroup() {
        XCTAssertThrowsError(
            try CommandInputResolver.resolveNamedSecretInput(
                shorthand: nil,
                group: nil,
                subgroup: "dev",
                name: "github"
            )
        ) { error in
            XCTAssertTrue(String(describing: error).contains("The --subgroup option requires --group."))
        }
    }

    func testCreateInputParsesGroupAndSubgroupShorthand() throws {
        let input = try CommandInputResolver.resolveCreateInput(
            shorthand: "myproject:dev",
            group: nil,
            subgroup: nil
        )

        XCTAssertEqual(input.group, "myproject")
        XCTAssertEqual(input.subgroup, "dev")
    }

    func testListScopeKeepsExplicitGroupAndSubgroup() throws {
        let scope = try CommandInputResolver.resolveListScope(group: "myproject", subgroup: "dev")
        XCTAssertEqual(scope, SecretScopeInput(group: "myproject", subgroup: "dev"))
    }
}
