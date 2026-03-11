import Noora
import XCTest
@testable import swift_passCore

final class ListCommandTests: XCTestCase {
    func testValidateOutputOptionsRejectsPlainAndInteractiveTogether() {
        var command = ListCommand()
        command.plain = true
        command.interactive = true

        XCTAssertThrowsError(try command.validateOutputOptions()) { error in
            XCTAssertEqual(
                String(describing: error),
                "The --plain and --interactive options cannot be used together."
            )
        }
    }

    func testPlainLinesContainOnlySecretNames() throws {
        let command = ListCommand()
        let entries = [
            try makeEntry(scope: SecretScope(group: "default"), name: "github", modificationDate: Date()),
            try makeEntry(scope: SecretScope(group: "default"), name: "openai", modificationDate: nil),
        ]

        XCTAssertEqual(command.plainLines(for: entries), ["github", "openai"])
    }

    func testFormattedModificationDateUsesFallbackWhenMissing() {
        XCTAssertEqual(ListCommand.formattedModificationDate(nil), "--")
    }

    func testTableRowShowsFullScopePathForSubgroupSecret() throws {
        let entry = try makeEntry(
            scope: SecretScope(group: "project", subgroup: "dev"),
            name: "github",
            modificationDate: Date(timeIntervalSince1970: 1_736_082_000)
        )

        let row = ListCommand.tableRow(for: entry)

        XCTAssertEqual(row.map { $0.plain() }, ["github", "2025-01-05 15:00", "project:dev"])
    }

    func testTableDataUsesExpectedHeaders() throws {
        let data = ListCommand.tableData(for: [
            try makeEntry(scope: SecretScope(group: "default"), name: "github", modificationDate: nil),
        ])

        XCTAssertEqual(data.columns.map { $0.title.plain() }, ["name", "date modified", "group name"])
    }

    private func makeEntry(
        scope: SecretScope,
        name: String,
        modificationDate: Date?
    ) throws -> SecretListEntry {
        SecretListEntry(
            reference: try SecretReference(scope: scope, name: name),
            modificationDate: modificationDate
        )
    }
}
