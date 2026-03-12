import ArgumentParser
import Noora
import XCTest
@testable import swift_passCore

final class GroupsCommandTests: XCTestCase {
    func testConfigurationIncludesGsAlias() {
        XCTAssertEqual(GroupsCommand.configuration.aliases, ["gs"])
    }

    func testValidateOutputOptionsRejectsPlainAndInteractiveTogether() {
        var command = GroupsCommand()
        command.plain = true
        command.interactive = true

        XCTAssertThrowsError(try command.validateOutputOptions()) { error in
            XCTAssertEqual(
                String(describing: error),
                "The --plain and --interactive options cannot be used together."
            )
        }
    }

    func testGroupPlainLinesContainOnlyGroupNames() {
        let command = GroupsCommand()
        let entries = [
            GroupListEntry(group: "default", subgroups: [], secretCount: 0),
            GroupListEntry(group: "project", subgroups: ["dev"], secretCount: 2),
        ]

        XCTAssertEqual(command.groupPlainLines(for: entries), ["default", "project"])
    }

    func testSubgroupPlainLinesContainFullScopePaths() throws {
        let command = GroupsCommand()
        let entries = [
            SubgroupListEntry(
                scope: try SecretScope(group: "project", subgroup: "dev"),
                secretCount: 1
            ),
        ]

        XCTAssertEqual(command.subgroupPlainLines(for: entries), ["project:dev"])
    }

    func testGroupTableRowShowsSubgroupNamesAndSecretCount() {
        let row = GroupsCommand.groupTableRow(
            for: GroupListEntry(group: "project", subgroups: ["dev", "prod"], secretCount: 2)
        )

        XCTAssertEqual(row.map { $0.plain() }, ["project", "dev, prod", "2"])
    }

    func testSubgroupTableRowShowsSubgroupNameAndSecretCount() throws {
        let row = GroupsCommand.subgroupTableRow(
            for: SubgroupListEntry(
                scope: try SecretScope(group: "project", subgroup: "dev"),
                secretCount: 3
            )
        )

        XCTAssertEqual(row.map { $0.plain() }, ["dev", "3"])
    }

    func testGroupTableDataUsesExpectedHeaders() {
        let data = GroupsCommand.groupTableData(for: [
            GroupListEntry(
                group: "default",
                subgroups: [],
                secretCount: 0
            ),
        ])

        XCTAssertEqual(data.columns.map { $0.title.plain() }, ["group", "subgroups", "secrets"])
    }

    func testSubgroupTableDataUsesExpectedHeaders() throws {
        let data = GroupsCommand.subgroupTableData(for: [
            SubgroupListEntry(
                scope: try SecretScope(group: "default", subgroup: "dev"),
                secretCount: 0
            ),
        ])

        XCTAssertEqual(data.columns.map { $0.title.plain() }, ["subgroup", "secrets"])
    }
}
