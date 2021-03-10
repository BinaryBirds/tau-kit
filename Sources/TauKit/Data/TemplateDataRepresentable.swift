import Foundation

// MARK: - TemplateDataRepresentable Public Definition

/// Capable of being encoded as `TemplateData`.
///
/// As `TemplateData` has no direct initializers, adherants must implement `TemplateData` by using a public
/// static factory method from `TemplateData`  to produce itself.
///
/// - WARNING: If adherant is a reference-type object, *BE AWARE OF THREADSAFETY*
public protocol TemplateDataRepresentable {
    /// Converts `self` to `TemplateData`, returning `nil` if the conversion is not possible.
    var templateData: TemplateData { get }
    
    /// If the adherent has a single, specified `TemplateDataType` that is *always* returned, non-nil
    ///
    /// Default implementation provided
    static var templateDataType: TemplateDataType? { get }
}

public extension TemplateDataRepresentable {
    static var templateDataType: TemplateDataType? { nil }
}

// MARK: - Default Conformances

extension String: TemplateDataRepresentable {
    public static var templateDataType: TemplateDataType? { .string }
    public var templateData: TemplateData { .string(self) }
}

extension FixedWidthInteger {
    public var templateData: TemplateData { .int(Int(exactly: self)) }
}

extension Int8: TemplateDataRepresentable { public static var templateDataType: TemplateDataType? { .int } }
extension Int16: TemplateDataRepresentable { public static var templateDataType: TemplateDataType? { .int } }
extension Int32: TemplateDataRepresentable { public static var templateDataType: TemplateDataType? { .int } }
extension Int64: TemplateDataRepresentable { public static var templateDataType: TemplateDataType? { .int } }
extension Int: TemplateDataRepresentable { public static var templateDataType: TemplateDataType? { .int } }
extension UInt8: TemplateDataRepresentable { public static var templateDataType: TemplateDataType? { .int } }
extension UInt16: TemplateDataRepresentable { public static var templateDataType: TemplateDataType? { .int } }
extension UInt32: TemplateDataRepresentable { public static var templateDataType: TemplateDataType? { .int } }
extension UInt64: TemplateDataRepresentable { public static var templateDataType: TemplateDataType? { .int } }
extension UInt: TemplateDataRepresentable { public static var templateDataType: TemplateDataType? { .int } }

extension BinaryFloatingPoint {
    public var templateData: TemplateData { .double(Double(exactly: self)) }
}

extension Float: TemplateDataRepresentable { public static var templateDataType: TemplateDataType? { .double } }
extension Double: TemplateDataRepresentable { public static var templateDataType: TemplateDataType? { .double } }
#if arch(i386) || arch(x86_64)
extension Float80: TemplateDataRepresentable { public static var templateDataType: TemplateDataType? { .double } }
#endif

extension Bool: TemplateDataRepresentable {
    public static var templateDataType: TemplateDataType? { .bool }
    public var templateData: TemplateData { .bool(self) }
}

extension UUID: TemplateDataRepresentable {
    public static var templateDataType: TemplateDataType? { .string }
    public var templateData: TemplateData { .string(description) }
}

extension Date: TemplateDataRepresentable {
    public static var templateDataType: TemplateDataType? { .double }
    public var templateData: TemplateData { .double(timeIntervalSinceReferenceDate) }
}

extension Set: TemplateDataRepresentable where Element: TemplateDataRepresentable {
    public static var templateDataType: TemplateDataType? { .array }
    public var templateData: TemplateData { .array(map {$0.templateData}) }
}

extension Array: TemplateDataRepresentable where Element: TemplateDataRepresentable {
    public static var templateDataType: TemplateDataType? { .array }
    public var templateData: TemplateData { .array(map {$0.templateData}) }
}

extension Dictionary: TemplateDataRepresentable where Key == String, Value: TemplateDataRepresentable {
    public static var templateDataType: TemplateDataType? { .dictionary }
    public var templateData: TemplateData { .dictionary(mapValues {$0.templateData}) }
}

extension Optional: TemplateDataRepresentable where Wrapped: TemplateDataRepresentable {
    public static var templateDataType: TemplateDataType? { Wrapped.templateDataType }
    public var templateData: TemplateData { self?.templateData ?? .init(.nil(Self.templateDataType ?? .void)) }
}
