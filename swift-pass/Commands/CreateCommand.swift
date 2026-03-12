import ArgumentParser
import Noora

struct CreateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a group or subgroup.",
        discussion: "Creates <group> or <group>:<subgroup>. Creating an existing scope is a no-op."
    )

    @Argument(help: "The scope to create in the format <group> or <group>:<subgroup>.")
    var scope: String?

    @Option(help: "The group to create.")
    var group: String?

    @Option(help: "The subgroup to create.")
    var subgroup: String?

    func run() async throws {
        let input = try CommandInputResolver.resolveCreateInput(
            shorthand: scope,
            group: group,
            subgroup: subgroup
        )
        let resolvedScope = try input.resolvedScope()
        let created = try SecretVault().createScope(resolvedScope)

        if created {
            Noora().success(
                .alert(
                    "'\(resolvedScope.displayPath)' created",
                    takeaways: ["Created \(resolvedScope.locationDescription)."]
                )
            )

            return
        }

        Noora().info(
            .alert(
                "'\(resolvedScope.displayPath)' already exists",
                takeaways: ["No changes were needed."]
            )
        )
    }
}
