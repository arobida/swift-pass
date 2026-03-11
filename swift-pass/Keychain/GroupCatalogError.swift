import Foundation

enum GroupCatalogError: LocalizedError {
    case invalidIdentifier(kind: String, value: String)
    case defaultGroupNotConfigured
    case catalogCorrupted(String)
    case groupNotFound(String)
    case subgroupNotFound(group: String, subgroup: String)
    case nonInteractiveScopeCreationRequired(SecretScope)
    case operationCancelled(String)

    var errorDescription: String? {
        switch self {
        case let .invalidIdentifier(kind, value):
            return "The \(kind) '\(value)' is invalid. Use a non-empty value without ':' or '='."
        case .defaultGroupNotConfigured:
            return "No default group is configured. Run 'swift-pass create default' or 'swift-pass set \"name=value\"' to initialize the default group."
        case let .catalogCorrupted(reason):
            return "The stored group catalog could not be read (\(reason))."
        case let .groupNotFound(group):
            return "The group '\(group)' does not exist."
        case let .subgroupNotFound(group, subgroup):
            return "The subgroup '\(subgroup)' does not exist in group '\(group)'."
        case let .nonInteractiveScopeCreationRequired(scope):
            return "The \(scope.displayPath) scope does not exist. Run 'swift-pass create \"\(scope.displayPath)\"' first or use an interactive terminal to confirm creating it."
        case let .operationCancelled(message):
            return message
        }
    }
}
