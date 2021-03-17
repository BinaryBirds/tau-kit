/// A representation of a function parameter defintion - equivalent to a Swift parameter defintion
public struct CallParameter: TemplatePrintable, Equatable {
    let label: String?
    let types: Set<TemplateDataType>
    let optional: Bool
    let defaultValue: Optional<TemplateData>

    /// Direct equivalency to a Swift parameter - see examples below
    ///
    /// For "func aFunction(`myLabel 0: String? = nil`)" (parameter will be available at `params["myLabel"]` or `params[0]`:
    ///    - `.init(label: "myLabel", types: [.string], optional: true, defaultValue: nil)`
    ///
    /// For "func aFunction(`_ 0: TemplateData")` (parameter will be available at `params[0]`:
    ///    - `.init(types: Set(TemplateDataType.allCases)) `
    public init(label: String? = nil,
                types: Set<TemplateDataType>,
                optional: Bool = false,
                defaultValue: Optional<TemplateData> = .none) {
        self.label = label
        self.types = types
        self.optional = optional
        self.defaultValue = defaultValue
        _sanity()
    }
    
    /// `(value(1), isValid: bool(true), ...)`
    public var description: String { short }
    var short: String {
        "\(label ?? "_"): \(types.map {$0.short.capitalized}.sorted(by: <).joined(separator: "|"))\(optional ? "?" : "")\(defaulted ? " = \(defaultValue!.container.terse)" : "")"
    }
    
    var defaulted: Bool { defaultValue != .none }
    var labeled: Bool { label != nil }
}

public extension CallParameter {
    /// Shorthand convenience for an unlabled, non-optional, undefaulted parameter of a single type
    static func type(_ type: TemplateDataType) -> Self { .init(types: [type]) }
    
    /// Shorthand convenience for an unlabled, non-optional, undefaulted parameter of `[types]`
    static func types(_ types: Set<TemplateDataType>) -> Self { .init(types: types) }
    
    /// Shorthand convenience for an unlabled, undefaulted parameter of `[types]?`
    static func optionalTypes(_ types: Set<TemplateDataType>) -> Self { .init(types: types, optional: true) }
    
    /// Any `TemplateDataType` but `.void` (and implicitly not an errored state value)
    static var any: Self { .types(.any) }
    
    /// `TemplateDataType` == `Collection`
    static var collections: Self { .types(.collections) }
    
    /// `TemplateDataType` == `SignedNumeric`
    static var numerics: Self { .types(.numerics) }
    
    /// Unlabeled, non-optional, undefaulted `.string`
    static var string: Self { .type(.string) }
    
    /// Unlabeled, non-optional, undefaulted `.int`
    static var int: Self { .type(.int) }
    
    /// Unlabeled, non-optional, undefaulted `.double`
    static var double: Self { .type(.double) }
        
    /// Unlabeled, non-optional, undefaulted `.bool`
    static var bool: Self { .type(.bool) }
    
    /// Unlabeled, non-optional, undefaulted `.data`
    static var data: Self { .type(.data) }
    
    /// Unlabeled, non-optional, undefaulted `.array`
    static var array: Self { .type(.array) }
    
    /// Unlabeled, non-optional, undefaulted `.dictionary`
    static var dictionary: Self { .type(.dictionary) }
    
    /// string-only with conveniences for various options
    static func string(labeled: String?, optional: Bool = false, defaultValue: Optional<TemplateData> = .none) -> Self {
        .init(label: labeled, types: .string, optional: optional, defaultValue: defaultValue) }
    
    /// double-only with conveniences for various options
    static func double(labeled: String?, optional: Bool = false, defaultValue: Optional<TemplateData> = .none) -> Self {
        .init(label: labeled, types: .double, optional: optional, defaultValue: defaultValue) }
    
    /// int-only with conveniences for various options
    static func int(labeled: String?, optional: Bool = false, defaultValue: Optional<TemplateData> = .none) -> Self {
        .init(label: labeled, types: .int, optional: optional, defaultValue: defaultValue) }
    
    /// bool-only with conveniences for various options
    static func bool(labeled: String?, optional: Bool = false, defaultValue: Optional<TemplateData> = .none) -> Self {
        .init(label: labeled, types: .bool, optional: optional, defaultValue: defaultValue) }
}

internal extension CallParameter {
    /// Verify the `CallParameter` is valid
    func _sanity() {
        precondition(!types.isEmpty,
                     "Parameter must specify at least one type")
        precondition(!types.contains(.void),
                     "Parameters cannot take .void types")
        precondition(!(label?.isEmpty ?? false) && label != "_",
                     "Use nil for unlabeled parameters, not empty strings or _")
        precondition(label?.isValidIdentifier ?? true,
                     "Label must be a valid, non-keyword identifier")
        precondition(types.contains(defaultValue?.storedType ?? types.first!),
                     "Default value is not a match for the argument types")
    }
    
    /// Return the parameter value if it's valid, coerce if possible, nil if not an interpretable match.
    func match(_ value: TemplateData) -> Optional<TemplateData> {
        /// 1:1 expected match, valid as long as expectation isn't non-optional with optional value
        if types.contains(value.storedType) { return !value.isNil || optional ? value : .none }
        /// If value is still nil but no match...
        if value.isNil {
            /// trueNil param
            if value.storedType == .void || !optional {
                                  /// param accepts optional, coerce nil type to an expected type
                return optional ? .init(.nil(types.first!))
                                  /// or if it takes bool, coerce to a false boolean or fail
                                : types.contains(.bool) ? .bool(false) : .none
            }
            /// Remaining nil values are failures
            return .none
        }
        /// If only one type, return coerced value as long as it doesn't coerce to .trueNil (and for .bool always true)
        if types.count == 1 {
            let coerced = value.coerce(to: types.first!)
            return !coerced.isTrueNil ? coerced : types.first! == .bool ? .bool(true) : .none
        }
        /// Otherwise assume function will handle coercion itself as long as one potential match exists
        return types.first(where: {value.isCoercible(to: $0)}) != nil ? value : .none
    }
}
