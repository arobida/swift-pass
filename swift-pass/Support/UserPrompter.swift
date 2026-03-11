import Darwin
import Noora

protocol UserPrompter {
    func textInput(
        title: String,
        prompt: String,
        description: String?,
        defaultValue: String?
    ) -> String
    func confirm(
        title: String?,
        question: String,
        defaultAnswer: Bool,
        description: String?
    ) -> Bool
}

struct NooraPrompter: UserPrompter {
    private let noora: Noora

    init(noora: Noora = Noora()) {
        self.noora = noora
    }

    func textInput(
        title: String,
        prompt: String,
        description: String? = nil,
        defaultValue: String? = nil
    ) -> String {
        noora.textPrompt(
            title: TerminalText(stringLiteral: title),
            prompt: TerminalText(stringLiteral: prompt),
            description: description.map { TerminalText(stringLiteral: $0) },
            defaultValue: defaultValue,
            validationRules: [NonEmptyValidationRule(error: "\(title) cannot be empty.")]
        )
    }

    func confirm(
        title: String?,
        question: String,
        defaultAnswer: Bool = true,
        description: String? = nil
    ) -> Bool {
        noora.yesOrNoChoicePrompt(
            title: title.map { TerminalText(stringLiteral: $0) },
            question: TerminalText(stringLiteral: question),
            defaultAnswer: defaultAnswer,
            description: description.map { TerminalText(stringLiteral: $0) }
        )
    }
}

struct CLIEnvironment {
    let isInteractive: Bool

    static let live = CLIEnvironment(
        isInteractive: isatty(STDIN_FILENO) != 0 && isatty(STDOUT_FILENO) != 0
    )
}
