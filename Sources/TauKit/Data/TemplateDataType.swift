/// The concrete instantiable object types for `TemplateData`
public enum TemplateDataType: UInt8, CaseIterable, Hashable {
    // MARK: Cases
    case bool
    case string
    case int
    case double
    case data
    case dictionary
    case array
    
    case void

    public var description: String { short }
}

public extension Set where Element == TemplateDataType {
    /// Any `TemplateDataType` but `.void`
    static var any: Self { Set(TauKit.TemplateDataType.allCases.filter {$0.returnable}) }
    /// `TemplateDataType` == `Collection`
    static var collections: Self { [.array, .dictionary] }
    /// `TemplateDataType` == `SignedNumeric`
    static var numerics: Self { [.int, .double] }
    
    static var string: Self { [.string] }
    static var int: Self { [.int] }
    static var double: Self { [.double] }
    static var void: Self { [.void] }
    static var bool: Self { [.bool] }
    static var array: Self { [.array] }
    static var dictionary: Self { [.dictionary] }
    static var data: Self { [.data] }
}

// MARK: - Internal Only
extension TemplateDataType: TemplatePrintable {
    internal var short: String {
        switch self {
            case .array      : return "array"
            case .bool       : return "bool"
            case .data       : return "data"
            case .dictionary : return "dictionary"
            case .double     : return "double"
            case .int        : return "int"
            case .string     : return "string"
            case .void       : return "void"
        }
    }

    /// Get the casting level for two types
    internal func casts(to type: Self) -> TemplateDataConversion {
        typealias _Map = TemplateDataConverters
        switch self {
            case .array      : return _Map.arrayMaps[type]!.is
            case .bool       : return _Map.boolMaps[type]!.is
            case .data       : return _Map.dataMaps[type]!.is
            case .dictionary : return _Map.dictionaryMaps[type]!.is
            case .double     : return _Map.doubleMaps[type]!.is
            case .int        : return _Map.intMaps[type]!.is
            case .string     : return _Map.stringMaps[type]!.is
            case .void       : return .ambiguous
        }
    }
    
    internal var returnable: Bool { self != .void }
}
