// MARK: - Public Implementation

public extension Renderer.Option {
    /// The current global configuration for rendering options
    static var allCases: [Self] {[
        .timeout(Self.$timeout._unsafeValue),
        .parseWarningThrows(Self.$parseWarningThrows._unsafeValue),
        .missingVariableThrows(Self.$missingVariableThrows._unsafeValue),
        .grantUnsafeEntityAccess(Self.$grantUnsafeEntityAccess._unsafeValue),
        .encoding(Self.$encoding._unsafeValue),
        .caching(Self.$caching._unsafeValue),
        .pollingFrequency(Self.$pollingFrequency._unsafeValue),
        .embeddedASTRawLimit(Self.$embeddedASTRawLimit._unsafeValue)
    ]}
    
    func hash(into hasher: inout Hasher) { hasher.combine(celf) }
    static func ==(lhs: Self, rhs: Self) -> Bool { lhs.celf == rhs.celf }
}

public extension Renderer.Options {
    /// All global settings for options on `Renderer`
    static var globalSettings: Self { .init(Renderer.Option.allCases) }
    
    init(_ elements: [Renderer.Option]) {
        self._storage = elements.reduce(into: []) {
            if !$0.contains($1) && $1.valid == true { $0.update(with: $1) } }
    }
    
    init(arrayLiteral elements: Renderer.Option...) { self.init(elements) }
    
    
    /// Unconditionally update the `Options` with the provided `option`
    @discardableResult
    mutating func update(_ option: Renderer.Option) -> Bool {
        let result = option.valid
        if result == false { return false }
        if result == nil { _storage.remove(option) } else { _storage.update(with: option) }
        return true
    }
    
    /// Unconditionally remove the `Options` with the provided `option`
    mutating func unset(_ option: Renderer.Option.Case) {
        if let x = _storage.first(where: {$0.celf == option}) { _storage.remove(x) } }
}

// MARK: - Internal Implementation

internal extension Renderer.Option {
    var celf: Case {
        switch self {
            case .timeout                 : return .timeout
            case .parseWarningThrows      : return .parseWarningThrows
            case .missingVariableThrows   : return .missingVariableThrows
            case .grantUnsafeEntityAccess : return .grantUnsafeEntityAccess
            case .encoding                : return .encoding
            case .caching                 : return .caching
            case .embeddedASTRawLimit     : return .embeddedASTRawLimit
            case .pollingFrequency        : return .pollingFrequency
        }
    }
    
    /// Validate that the local setting for an option is acceptable or ignorable (matches global setting)
    var valid: Bool? {
        switch self {
            case .parseWarningThrows(let b)      : return Self.$parseWarningThrows.validate(b)
            case .missingVariableThrows(let b)   : return Self.$missingVariableThrows.validate(b)
            case .grantUnsafeEntityAccess(let b) : return Self.$grantUnsafeEntityAccess.validate(b)
            case .timeout(let t)                 : return Self.$timeout.validate(t)
            case .encoding(let e)                : return Self.$encoding.validate(e)
            case .caching(let c)                 : return Self.$caching.validate(c)
            case .embeddedASTRawLimit(let l)     : return Self.$embeddedASTRawLimit.validate(l)
            case .pollingFrequency(let d)        : return Self.$pollingFrequency.validate(d)
        }
    }
}

internal extension Renderer.Options {
    subscript(key: Renderer.Option.Case) -> Renderer.Option? {
        _storage.first(where: {$0.celf == key}) }
}
