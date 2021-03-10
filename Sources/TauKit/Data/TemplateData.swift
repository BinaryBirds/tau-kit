import Foundation

// MARK: - TemplateData Public Definition

/// `TemplateData` is a "pseudo-protocol" wrapping the physically storable Swift data types
/// the template engine can use directly
/// - `(Bool, Int, Double, String, Array, Dictionary, Data)` are the inherent root types
///     supported, all of which may also be representable as `Optional` values.
/// - `CaseType` presents these cases plus `Void` as a case for functional `Symbols`
/// - `nil` is creatable, but only within context of a root base type - eg, `.nil(.bool)` == `Bool?`
public struct TemplateData: TemplateDataRepresentable, Equatable {

    // MARK: - Stored Properties

    /// Concrete stored type of the data
    public let storedType: TemplateDataType
    /// Actual storage
    let container: TemplateDataContainer
    /// State storage flags
    let state: State

    // MARK: - Custom String Convertible Conformance
    public var description: String { container.description }

    // MARK: - Equatable Conformance
    public static func ==(lhs: TemplateData, rhs: TemplateData) -> Bool {
        // Strict compare of invariant stored values; considers .nil & .void equal
        guard !(lhs.container == rhs.container) else { return true }
        // If either side is nil, false - container == would have returned false
        guard !lhs.isNil && !rhs.isNil else { return false }
        // - Lazy variant data should never be tested due to potential side-effects
        guard lhs.invariant && rhs.invariant else { return false }
        // Fuzzy comparison by string casting
        guard lhs.isCastable(to: .string),
              rhs.isCastable(to: .string),
              let lhs = lhs.string, let rhs = rhs.string else { return false }
        return lhs == rhs
    }

    // MARK: - State

    /// Returns `true` if concrete object can be exactly or losslessly cast to a second type
    /// - EG: `.nil ` -> `.string("")`, `.int(1)` ->  `.double(1.0)`,
    ///      `.bool(true)` -> `.string("true")` are all one-way lossless conversions
    /// - This does not imply it's not possible to *coerce* data - handle with `coerce(to:)`
    ///   EG: `.string("")` -> `.nil`, `.string("1")` -> ` .bool(true)`
    public func isCastable(to type: TemplateDataType) -> Bool { storedType.casts(to: type) >= .castable }

    /// Returns `true` if concrete object is potentially directly coercible to a second type in some way
    /// - EG: `.array()` -> `.dictionary()` where array indices become keys
    ///       or `.int(1)` -> `.bool(true)`
    /// - This does *not* validate the data itself in coercion
    public func isCoercible(to type: TemplateDataType) -> Bool { storedType.casts(to: type) >= .coercible }

    // MARK: - TemplateDataRepresentable
    public var templateData: TemplateData { self }
    
    // MARK: - Swift Type Extraction

    /// Attempts to convert to `Bool`: if a nil optional Bool, returns `nil` - returns t/f if bool-evaluated.
    /// Anything that is tangible but not evaluable to bool reports on its optional-ness as truth.
    public var bool: Bool? {
        if case .bool(let b) = container { return b }
        guard case .bool(let b) = coerce(to: .bool).container else { return nil }
        return b
    }

    /// Attempts to convert to `String` or returns `nil`.
    public var string: String? {
        if case .string(let s) = container { return s }
        guard case .string(let s) = coerce(to: .string).container else { return nil }
        return s
    }

    /// Attempts to convert to `Int` or returns `nil`.
    public var int: Int? {
        if case .int(let i) = container { return i }
        guard case .int(let i) = coerce(to: .int).container else { return nil }
        return i
    }

    /// Attempts to convert to `Double` or returns `nil`.
    public var double: Double? {
        if case .double(let d) = container { return d }
        guard case .double(let d) = coerce(to: .double).container else { return nil }
        return d
    }

    /// Attempts to convert to `Data` or returns `nil`.
    public var data: Data? {
        if case .data(let d) = container { return d }
        guard case .data(let d) = coerce(to: .data).container else { return nil }
        return d
    }

    /// Attempts to convert to `[String: TemplateData]` or returns `nil`.
    public var dictionary: [String: TemplateData]? {
        if case .dictionary(let d) = container { return d }
        guard case .dictionary(let d) = coerce(to: .dictionary).container else { return nil }
        return d
    }

    /// Attempts to convert to `[TemplateData]` or returns `nil`.
    public var array: [TemplateData]? {
        if case .array(let a) = container { return a }
        guard case .array(let a) = coerce(to: .array).container else { return nil }
        return a
    }

    /// For convenience, `trueNil` is stored as `.optional(nil, .void)`
    public static let trueNil: TemplateData = .nil(.void)
}

// MARK: - Public Initializers
extension TemplateData: ExpressibleByDictionaryLiteral,
                    ExpressibleByStringLiteral,
                    ExpressibleByIntegerLiteral,
                    ExpressibleByBooleanLiteral,
                    ExpressibleByArrayLiteral,
                    ExpressibleByFloatLiteral,
                    ExpressibleByNilLiteral,
                    ExpressibleByStringInterpolation {
    // MARK: Generic `TemplateDataRepresentable` Initializer
    public init(_ TemplateData: TemplateDataRepresentable) { self = TemplateData.templateData }

    // MARK: Static Initializer Conformances
    /// Creates a new `TemplateData` from a `Bool`.
    public static func bool(_ value: Bool?) -> Self {
        value.map { Self(.bool($0)) } ?? .nil(.bool) }
    /// Creates a new `TemplateData` from a `String`.
    public static func string(_ value: String?) -> Self {
        value.map { Self(.string($0)) } ?? .nil(.string) }
    /// Creates a new `TemplateData` from am `Int`.
    public static func int(_ value: Int?) -> Self {
        value.map { Self(.int($0)) } ?? .nil(.int) }
    /// Creates a new `TemplateData` from a `Double`.
    public static func double(_ value: Double?) -> Self {
        value.map { Self(.double($0)) } ?? .nil(.double) }
    /// Creates a new `TemplateData` from `Data`.
    public static func data(_ value: Data?) -> Self {
        value.map { Self(.data($0)) } ?? .nil(.data) }
    /// Creates a new `TemplateData` from `[String: TemplateData]`.
    public static func dictionary(_ value: [String: TemplateData]?) -> Self {
        value.map { Self(.dictionary($0)) } ?? .nil(.dictionary) }
    /// Creates a new `TemplateData` from `[String: TemplateDataRepresentable]`.
    public static func dictionary(_ value: [String: TemplateDataRepresentable]?) -> Self {
        dictionary(value?.mapValues { $0.templateData }) }
    /// Creates a new `TemplateData` from `[TemplateData]`.
    public static func array(_ value: [TemplateData]?) -> Self {
        value.map { Self(.array($0)) } ?? .nil(.array) }
    /// Creates a new `TemplateData` from `[TemplateDataRepresentable]`.
    public static func array(_ value: [TemplateDataRepresentable]?) -> Self {
        array(value?.map {$0.templateData}) }
    /// Creates a new `TemplateData` for `Optional<TemplateData>`
    public static func `nil`(_ type: TemplateDataType) -> Self {
        Self(.nil(type)) }
    
    public static func error(_ reason: String,
                             function: String = #function) -> Self {
        Self(.error(reason, function, nil))
    }

    // MARK: Literal Initializer Conformances
    public init(nilLiteral: ()) { self = .trueNil }
    public init(stringLiteral value: StringLiteralType) { self = value.templateData }
    public init(integerLiteral value: IntegerLiteralType) { self = value.templateData }
    public init(floatLiteral value: FloatLiteralType) { self = value.templateData }
    public init(booleanLiteral value: BooleanLiteralType) { self = value.templateData }
    public init(arrayLiteral elements: TemplateData...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, TemplateData)...) {
        self = .dictionary(.init(uniqueKeysWithValues: elements)) }
}

// MARK: - Internal Only
extension TemplateData: Symbol {
    /// Creates a new `TemplateData`.
    init(_ raw: TemplateDataContainer) {
        self.container = raw
        self.storedType = raw.baseType
        self.state = raw.state
    }
    
    static func error(internal reason: String,
                             _ function: String = "TauKit",
                             _ location: SourceLocation? = nil) -> Self {
        Self(.error(reason, "TauKit", location))
    }
    
    /// Creates a new `TemplateData` from `() -> TemplateData` if possible or `nil` if not possible.
    /// `returns` must specify a `CaseType` that the function will return
    static func lazy(_ lambda: @escaping () -> TemplateData, returns type: TemplateDataType) -> Self {
        Self(.lazy(f: lambda, returns: type))
    }
    
    var errored: Bool { state.rawValue == 0 }
    var error: String? { !errored ? nil : container.error! }

    /// Note - we don't consider an optional container true for this purpose
    var isTrueNil    : Bool { state == .trueNil }
    var isCollection : Bool { state.contains(.collection) }
    var isNil        : Bool { state.contains(.nil) }
    var isNumeric    : Bool { state.contains(.numeric) }
    var isComparable : Bool { state.contains(.comparable) }
    var isLazy       : Bool { state.contains(.variant) }

    /// Returns `true` if the object has a single uniform type
    /// - Always true for invariant non-containers
    /// - True or false for containers if determinable
    /// - Nil if the object is variant lazy data, or invariant lazy producing a container, or a container holding such
    var hasUniformType: Bool? { !isCollection ? true : uniformType.map {_ in true } ?? false }

    /// Returns the uniform type of the object, or nil if it can't be determined/is a non-uniform container
    var uniformType: TemplateDataType? {
        // Default case - anything that doesn't return a container, or lazy containers
        if !isCollection { return storedType } else if isLazy { return nil }
        // A non-lazy container - somewhat expensive to check. 0 or 1 element
        // is always uniform of that type. Only 1 layer deep, considers collection
        // elements, even if all the same type, unequal
        if case .array(let a) = container {
            guard a.count > 1 else { return a.first?.storedType }
            if a.first!.isCollection { return nil }
            let types = a.reduce(into: Set<TemplateDataType>.init(), { $0.insert($1.storedType) })
            return types.count == 1 ? types.first! : nil
        } else if case .dictionary(let d) = container {
            guard d.count > 1 else { return d.values.first?.storedType }
            if d.values.first!.isCollection { return nil }
            let types = d.values.reduce(into: Set<TemplateDataType>.init(), { $0.insert($1.storedType) })
            return types.count == 1 ? types.first! : nil
        } else { return nil }
    }

    func cast(to: TemplateDataType) -> Self   { convert(to: to, .castable) }
    func coerce(to: TemplateDataType) -> Self { convert(to: to, .coercible) }

    /// Try to convert one concrete object to a second type. Special handling for optional converting to bool.
    func convert(to output: TemplateDataType, _ level: TemplateDataConversion = .castable) -> Self {
        typealias _Map = TemplateDataConverters
        /// If celf is identity, return directly if invariant or return lazy evaluation
        if storedType == output { return invariant ? self : container.evaluate }
        /// If nil, no casting is possible between types *Except* special case of void -> bool(false)
        if isNil { return output == .bool && storedType == .void ? .bool(false) : .trueNil }

        let input = !container.isLazy ? container : container.evaluate.container
        switch input {
            case .array(let a)      : let m = _Map.arrayMaps[output]!
                                      return m.is >= level ? m.via(a) : .trueNil
            case .bool(let b)       : let m = _Map.boolMaps[output]!
                                      return m.is >= level ? m.via(b) : .trueNil
            case .data(let d)       : let m = _Map.dataMaps[output]!
                                      return m.is >= level ? m.via(d) : .trueNil
            case .dictionary(let d) : let m = _Map.dictionaryMaps[output]!
                                      return m.is >= level ? m.via(d) : .trueNil
            case .double(let d)     : let m = _Map.doubleMaps[output]!
                                      return m.is >= level ? m.via(d) : .trueNil
            case .int(let i)        : let m = _Map.intMaps[output]!
                                      return m.is >= level ? m.via(i) : .trueNil
            case .string(let s)     : let m = _Map.stringMaps[output]!
                                      return m.is >= level ? m.via(s) : .trueNil
            default                 : return .trueNil
        }
    }

    // MARK: - Symbol Conformance
    var short: String { container.short }
    var resolved: Bool { !state.contains(.variant) }
    var invariant: Bool { !state.contains(.variant) }
    var symbols: Set<Variable> { [] }

    func resolve(_ symbols: inout VariableStack) -> Self { self }
    func evaluate(_ symbols: inout VariableStack) -> Self { state.contains(.variant) ? container.evaluate : self }
}

