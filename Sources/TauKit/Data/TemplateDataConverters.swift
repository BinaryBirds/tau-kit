// MARK: Stable?!!

import Foundation

// MARK: - Data Converter Static Mapping

/// Stages of convertibility
internal enum TemplateDataConversion: UInt8, Hashable, Comparable {
    /// Not implicitly convertible automatically
    case ambiguous = 0
    /// A coercion with a clear meaning in one direction
    case coercible = 1
    /// A conversion with a well-defined bi-directional casting possibility
    case castable = 2
    /// An exact type match; identity
    case identity = 3

    static func <(lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Map of functions for converting between concrete, non-nil TemplateData
///
/// Purely for pass-through identity, casting, or coercing between the concrete types (Bool, Int, Double,
/// String, Array, Dictionary, Data) and will never attempt to handle optionals, which must *always*
/// be unwrapped to concrete types before being called.
///
/// Converters are guaranteed to be provided non-nil input. Failable converters must return TemplateData.trueNil
internal enum TemplateDataConverters {
    typealias ArrayMap = (`is`: TemplateDataConversion, via: ([TemplateData]) -> TemplateData)
    static let arrayMaps: [TemplateDataType: ArrayMap] = [
        .array      : (is: .identity, via: { .array($0) }),

        .bool       : (is: .coercible, via: { _ in .bool(true) }),

        .data       : (is: .ambiguous, via: { _ in .trueNil }),
        .double     : (is: .ambiguous, via: { _ in .trueNil }),
        .dictionary : (is: .ambiguous, via: { _ in .trueNil }),
        .int        : (is: .ambiguous, via: { _ in .trueNil }),
        .string     : (is: .ambiguous, via: { _ in .trueNil })
    ]

    typealias BoolMap = (`is`: TemplateDataConversion, via: (Bool) -> TemplateData)
    static let boolMaps: [TemplateDataType: BoolMap] = [
        .bool       : (is: .identity, via: { .bool($0) }),

        .double     : (is: .castable, via: { .double($0 ? 1.0 : 0.0) }),
        .int        : (is: .castable, via: { .int($0 ? 1 : 0) }),
        .string     : (is: .castable, via: { .string($0.description) }),

        .array      : (is: .ambiguous, via: { _ in .trueNil }),
        .data       : (is: .ambiguous, via: { _ in .trueNil }),
        .dictionary : (is: .ambiguous, via: { _ in .trueNil })
    ]

    typealias DataMap = (`is`: TemplateDataConversion, via: (Data) -> TemplateData)
    static let dataMaps: [TemplateDataType: DataMap] = [
        .data       : (is: .identity, via: { .data($0) }),

        .bool       : (is: .coercible, via: { _ in .bool(true) }),

        .array      : (is: .ambiguous, via: { _ in .trueNil }),
        .dictionary : (is: .ambiguous, via: { _ in .trueNil }),
        .double     : (is: .ambiguous, via: { _ in .trueNil }),
        .int        : (is: .ambiguous, via: { _ in .trueNil }),
        .string     : (is: .ambiguous, via: { _ in .trueNil })
    ]

    typealias DictionaryMap = (`is`: TemplateDataConversion, via: ([String: TemplateData]) -> TemplateData)
    static let dictionaryMaps: [TemplateDataType: DictionaryMap] = [
        .dictionary : (is: .identity, via: { .dictionary($0) }),

        .bool       : (is: .coercible, via: { _ in .bool(true) }),

        .array      : (is: .ambiguous, via: { _ in .trueNil }),
        .data       : (is: .ambiguous, via: { _ in .trueNil }),
        .double     : (is: .ambiguous, via: { _ in .trueNil }),
        .int        : (is: .ambiguous, via: { _ in .trueNil }),
        .string     : (is: .ambiguous, via: { _ in .trueNil })
    ]

    typealias DoubleMap = (`is`: TemplateDataConversion, via: (Double) -> TemplateData)
    static let doubleMaps: [TemplateDataType: DoubleMap] = [
        .double     : (is: .identity, via: { $0.templateData }),

        .bool       : (is: .castable, via: { .bool($0 != 0.0) }),
        .string     : (is: .castable, via: { .string($0.description) }),

        .int        : (is: .coercible, via: { .int(Int(exactly: $0.rounded())) }),

        .array      : (is: .ambiguous, via: { _ in .trueNil }),
        .data       : (is: .ambiguous, via: { _ in .trueNil }),
        .dictionary : (is: .ambiguous, via: { _ in .trueNil }),
    ]

    typealias IntMap = (`is`: TemplateDataConversion, via: (Int) -> TemplateData)
    static let intMaps: [TemplateDataType: IntMap] = [
        .int        : (is: .identity, via: { $0.templateData }),

        .bool       : (is: .castable, via: { .bool($0 != 0) }),
        .double     : (is: .castable, via: { .double(Double($0)) }),
        .string     : (is: .castable, via: { .string($0.description) }),

        .array      : (is: .ambiguous, via: { _ in .trueNil }),
        .data       : (is: .ambiguous, via: { _ in .trueNil }),
        .dictionary : (is: .ambiguous, via: { _ in .trueNil }),
    ]

    typealias StringMap = (`is`: TemplateDataConversion, via: (String) -> TemplateData)
    static let stringMaps: [TemplateDataType: StringMap] = [
        .string     : (is: .identity, via: { $0.templateData }),

        .bool       : (is: .castable, via: {
                        .bool(Keyword(rawValue: $0.lowercased())?.bool ?? true) }),
        .double     : (is: .castable, via: { .double(Double($0)) }),
        .int        : (is: .castable, via: { .int(Int($0)) } ),

        .array      : (is: .ambiguous, via: { _ in .trueNil }),
        .data       : (is: .ambiguous, via: { _ in .trueNil }),
        .dictionary : (is: .ambiguous, via: { _ in .trueNil }),
    ]
}
