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
    var TemplateData: TemplateData { get }
    
    /// If the adherent has a single, specified `TemplateDataType` that is *always* returned, non-nil
    ///
    /// Default implementation provided
    static var TemplateDataType: TemplateDataType? { get }
}

public extension TemplateDataRepresentable {
    static var TemplateDataType: TemplateDataType? { nil }
}

// MARK: - Default Conformances

extension String: TemplateDataRepresentable {
    public static var TemplateDataType: TemplateDataType? { .string }
    public var TemplateData: TemplateData { .string(self) }
}

extension FixedWidthInteger {
    public var TemplateData: TemplateData { .int(Int(exactly: self)) }
}

extension Int8: TemplateDataRepresentable { public static var TemplateDataType: TemplateDataType? { .int } }
extension Int16: TemplateDataRepresentable { public static var TemplateDataType: TemplateDataType? { .int } }
extension Int32: TemplateDataRepresentable { public static var TemplateDataType: TemplateDataType? { .int } }
extension Int64: TemplateDataRepresentable { public static var TemplateDataType: TemplateDataType? { .int } }
extension Int: TemplateDataRepresentable { public static var TemplateDataType: TemplateDataType? { .int } }
extension UInt8: TemplateDataRepresentable { public static var TemplateDataType: TemplateDataType? { .int } }
extension UInt16: TemplateDataRepresentable { public static var TemplateDataType: TemplateDataType? { .int } }
extension UInt32: TemplateDataRepresentable { public static var TemplateDataType: TemplateDataType? { .int } }
extension UInt64: TemplateDataRepresentable { public static var TemplateDataType: TemplateDataType? { .int } }
extension UInt: TemplateDataRepresentable { public static var TemplateDataType: TemplateDataType? { .int } }

extension BinaryFloatingPoint {
    public var TemplateData: TemplateData { .double(Double(exactly: self)) }
}

extension Float: TemplateDataRepresentable { public static var TemplateDataType: TemplateDataType? { .double } }
extension Double: TemplateDataRepresentable { public static var TemplateDataType: TemplateDataType? { .double } }
#if arch(i386) || arch(x86_64)
extension Float80: TemplateDataRepresentable { public static var TemplateDataType: TemplateDataType? { .double } }
#endif

extension Bool: TemplateDataRepresentable {
    public static var TemplateDataType: TemplateDataType? { .bool }
    public var TemplateData: TemplateData { .bool(self) }
}

extension UUID: TemplateDataRepresentable {
    public static var TemplateDataType: TemplateDataType? { .string }
    public var TemplateData: TemplateData { .string(description) }
}

extension Date: TemplateDataRepresentable {
    public static var TemplateDataType: TemplateDataType? { .double }
    public var TemplateData: TemplateData { .double(timeIntervalSinceReferenceDate) }
}

extension Set: TemplateDataRepresentable where Element: TemplateDataRepresentable {
    public static var TemplateDataType: TemplateDataType? { .array }
    public var TemplateData: TemplateData { .array(map {$0.TemplateData}) }
}

extension Array: TemplateDataRepresentable where Element: TemplateDataRepresentable {
    public static var TemplateDataType: TemplateDataType? { .array }
    public var TemplateData: TemplateData { .array(map {$0.TemplateData}) }
}

extension Dictionary: TemplateDataRepresentable where Key == String, Value: TemplateDataRepresentable {
    public static var TemplateDataType: TemplateDataType? { .dictionary }
    public var TemplateData: TemplateData { .dictionary(mapValues {$0.TemplateData}) }
}

extension Optional: TemplateDataRepresentable where Wrapped: TemplateDataRepresentable {
    public static var TemplateDataType: TemplateDataType? { Wrapped.TemplateDataType }
    public var TemplateData: TemplateData { self?.TemplateData ?? .init(.nil(Self.TemplateDataType ?? .void)) }
}
