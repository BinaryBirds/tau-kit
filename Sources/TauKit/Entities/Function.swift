// MARK: Subject to change prior to 1.0.0 release

/// An object that can take `TemplateData` parameters and returns a single `TemplateData` result
///
/// Example: `#date("now", "YYYY-mm-dd")`
public protocol Function {
    /// Array of the function's full call parameters
    ///
    /// *MUST BE STABLE AND NOT CHANGE*
    static var callSignature: [CallParameter] { get }

    /// The concrete type(s) of `TemplateData` the function returns
    ///
    /// *MUST BE STABLE AND NOT CHANGE* - if multiple possible types can be returned, use .any
    static var returns: Set<TemplateDataType> { get }

    /// Whether the function is invariant (has no potential side effects and always produces the same
    /// value given the same input)
    ///
    /// *MUST BE STABLE AND NOT CHANGE*
    static var invariant: Bool { get }

    /// The actual evaluation function of the `Function`, which will be called with fully resolved data
    func evaluate(_ params: CallValues) -> TemplateData
}

// MARK: - Convenience Protocols

public protocol EmptyParams: Function {}
public extension EmptyParams { static var callSignature: [CallParameter] {[]} }

public protocol Invariant: Function {}
public extension Invariant { static var invariant: Bool { true } }

public protocol StringReturn: Function {}
public extension StringReturn { static var returns: Set<TemplateDataType> { .string } }

public protocol VoidReturn: Function {}
public extension VoidReturn { static var returns: Set<TemplateDataType> { .void } }

public protocol BoolReturn: Function {}
public extension BoolReturn { static var returns: Set<TemplateDataType> { .bool } }

public protocol ArrayReturn: Function {}
public extension ArrayReturn { static var returns: Set<TemplateDataType> { .array } }

public protocol DictionaryReturn: Function {}
public extension DictionaryReturn { static var returns: Set<TemplateDataType> { .dictionary } }

public protocol IntReturn: Function {}
public extension IntReturn { static var returns: Set<TemplateDataType> { .int } }

public protocol DoubleReturn: Function {}
public extension DoubleReturn { static var returns: Set<TemplateDataType> { .double } }

public protocol DataReturn: Function {}
public extension DataReturn { static var returns: Set<TemplateDataType> { .data } }

public protocol AnyReturn: Function {}
public extension AnyReturn { static var returns: Set<TemplateDataType> { .any } }

// MARK: Internal Only

internal extension Function {
    var invariant: Bool { Self.invariant }
    var sig: [CallParameter] { Self.callSignature }
}
