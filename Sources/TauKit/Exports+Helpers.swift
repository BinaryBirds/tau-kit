@_exported import NIO

// MARK: Public Type Shorthands

public typealias ParseSignatures = [String: [ParseParameter]]

// MARK: - Static Conveniences

/// Public helper identities
public extension Character {
    static var tagIndicator: Self { TemplateConfiguration.tagIndicator }
    static var octothorpe: Self { "#".first! }
}

public extension String {
    /// Whether the string is valid as an identifier (variable part or function name) in TauKit
    var isValidIdentifier: Bool {
        !isEmpty && !isKeyword
            && first?.canStartIdentifier ?? false
            && allSatisfy({$0.isValidInIdentifier})
    }
    
    /// Whether the string is a (protected) keyword
    var isKeyword: Bool { Keyword(rawValue: self) != nil }
}
