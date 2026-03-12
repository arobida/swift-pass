import ArgumentParser
import Noora

struct GroupsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "groups",
        abstract: "List created groups or the subgroups in a group.",
        discussion: "Displays created groups from the catalog. Pass a group name to display that group's subgroups. By default this renders a table; use --plain for newline-delimited scope paths or --interactive to select a row.",
        aliases: ["gs"]
    )

    private static let interactivePageSize = 10

    @Argument(help: "The parent group to inspect for subgroups.")
    var group: String?

    @Flag(name: [.short, .long], help: "Present the results in an interactive selectable table.")
    var interactive = false

    @Flag(help: "Print newline-delimited group and subgroup paths for scripts and pipes.")
    var plain = false

    func run() async throws {
        try validateOutputOptions()

        let vault = SecretVault()

        if let group {
            let entries = try vault.subgroupListEntries(in: group)

            guard !entries.isEmpty else {
                Noora().info(
                    .alert(
                        "No subgroups created",
                        takeaways: ["Group '\(group)' has no subgroups."]
                    )
                )

                return
            }

            if plain {
                for line in subgroupPlainLines(for: entries) {
                    print(line)
                }

                return
            }

            let noora = Noora()
            let data = Self.subgroupTableData(for: entries)

            if interactive {
                let selectedIndex = try await noora.selectableTable(data, pageSize: Self.interactivePageSize)
                print(entries[selectedIndex].scope.displayPath)
                return
            }

            noora.table(data)
            return
        }

        let entries = try vault.groupListEntries()

        guard !entries.isEmpty else {
            Noora().info(
                .alert(
                    "No groups created",
                    takeaways: ["No groups have been created yet."]
                )
            )

            return
        }

        if plain {
            for line in groupPlainLines(for: entries) {
                print(line)
            }

            return
        }

        let noora = Noora()
        let data = Self.groupTableData(for: entries)

        if interactive {
            let selectedIndex = try await noora.selectableTable(data, pageSize: Self.interactivePageSize)
            print(entries[selectedIndex].group)
            return
        }

        noora.table(data)
    }

    func validateOutputOptions() throws {
        guard !(plain && interactive) else {
            throw ValidationError("The --plain and --interactive options cannot be used together.")
        }
    }

    func groupPlainLines(for entries: [GroupListEntry]) -> [String] {
        entries.map(\.group)
    }

    func subgroupPlainLines(for entries: [SubgroupListEntry]) -> [String] {
        entries.map(\.scope.displayPath)
    }

    static func groupTableData(for entries: [GroupListEntry]) -> TableData {
        let columns = [
            TableColumn(title: "group", width: .flexible(min: 8, max: 24), alignment: .left),
            TableColumn(title: "subgroups", width: .flexible(min: 12, max: 48), alignment: .left),
            TableColumn(title: "secrets", width: .fixed(8), alignment: .right),
        ]
        let rows = entries.map(groupTableRow(for:))
        return TableData(columns: columns, rows: rows)
    }

    static func subgroupTableData(for entries: [SubgroupListEntry]) -> TableData {
        let columns = [
            TableColumn(title: "subgroup", width: .flexible(min: 8, max: 32), alignment: .left),
            TableColumn(title: "secrets", width: .fixed(8), alignment: .right),
        ]
        let rows = entries.map(subgroupTableRow(for:))
        return TableData(columns: columns, rows: rows)
    }

    static func groupTableRow(for entry: GroupListEntry) -> [TerminalText] {
        [
            TerminalText(stringLiteral: entry.group),
            TerminalText(stringLiteral: entry.subgroups.isEmpty ? "--" : entry.subgroups.joined(separator: ", ")),
            TerminalText(stringLiteral: String(entry.secretCount)),
        ]
    }

    static func subgroupTableRow(for entry: SubgroupListEntry) -> [TerminalText] {
        [
            TerminalText(stringLiteral: entry.scope.subgroup ?? "--"),
            TerminalText(stringLiteral: String(entry.secretCount)),
        ]
    }
}
