import ArgumentParser
import Foundation
import Noora

struct ListCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all stored secrets.",
        discussion: "Displays secrets in the default group, a specific group, or a specific subgroup. Use <group> or <group>:<subgroup> for shorthand. By default this renders a table; use --plain for newline-delimited names or --interactive to select a row.",
        aliases: ["ls"]
    )

    private static let interactivePageSize = 10
    private static let modificationDateFormat = Date.VerbatimFormatStyle(
        format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits)",
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: .current,
        calendar: Calendar(identifier: .gregorian)
    )

    @Argument(help: "The scope to list in the format <group> or <group>:<subgroup>.")
    var scope: String?

    @Option(help: "The group to list. Omit it to list the default group.")
    var group: String?

    @Option(help: "The subgroup to list.")
    var subgroup: String?

    @Flag(name: [.short, .long], help: "Present the results in an interactive selectable table.")
    var interactive = false

    @Flag(help: "Print newline-delimited secret names for scripts and pipes.")
    var plain = false

    func run() async throws {
        try validateOutputOptions()

        let scopeInput = try CommandInputResolver.resolveListScope(
            shorthand: scope,
            group: group,
            subgroup: subgroup
        )
        let vault = SecretVault()
        let scope = try vault.resolveScope(scopeInput, forWrite: false)
        let entries = try vault.secretListEntries(in: scope)

        guard !entries.isEmpty else {
            Noora().info(
                .alert(
                    "No secrets stored",
                    takeaways: ["No secrets were found in \(scope.locationDescription)."]
                )
            )

            return
        }

        if plain {
            for line in plainLines(for: entries) {
                print(line)
            }

            return
        }

        let noora = Noora()
        let data = Self.tableData(for: entries)

        if interactive {
            let selectedIndex = try await noora.selectableTable(data, pageSize: Self.interactivePageSize)
            print(entries[selectedIndex].reference.displayPath)
            return
        }

        noora.table(data)
    }

    func validateOutputOptions() throws {
        try CommandValidation.validateOutputOptions(plain: plain, interactive: interactive)
    }

    func plainLines(for entries: [SecretListEntry]) -> [String] {
        entries.map(\.reference.name)
    }

    static func tableData(for entries: [SecretListEntry]) -> TableData {
        let columns = [
            TableColumn(title: "name", width: .flexible(min: 8, max: 40), alignment: .left),
            TableColumn(title: "date modified", width: .fixed(16), alignment: .left),
            TableColumn(title: "group name", width: .flexible(min: 12), alignment: .left),
        ]
        let rows = entries.map(tableRow(for:))
        return TableData(columns: columns, rows: rows)
    }

    static func tableRow(for entry: SecretListEntry) -> [TerminalText] {
        [
            TerminalText(stringLiteral: entry.reference.name),
            TerminalText(stringLiteral: formattedModificationDate(entry.modificationDate)),
            TerminalText(stringLiteral: entry.reference.scope.displayPath),
        ]
    }

    static func formattedModificationDate(_ date: Date?) -> String {
        guard let date else {
            return "--"
        }

        return date.formatted(Self.modificationDateFormat)
    }
}
