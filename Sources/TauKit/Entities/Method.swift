

/// A `Function` that additionally can be used on a method on concrete `TemplateData` types.
///
/// Example: `#(aStringVariable.hasPrefix("prefix")`
/// The first parameter of the `.callSignature` provides the types the method can operate on. The method
/// will still be called using `Function.evaluate`, with the first parameter being the operand.
///
/// Has the potential to mutate the first parameter it is passed; must either be mutating or non-mutating (not both).
///
/// Convenience protocols`(Non)MutatingMethod`s preferred for adherence as they provide default
/// implementations for the enforced requirements of those variations.
public protocol Method: Function {}

/// A `Method` that does not mutate its first parameter value.
public protocol NonMutatingMethod: Method {}

/// A `Method` that may potentially mutate its first parameter value.
public protocol MutatingMethod: Method {
    /// Return non-nil for `mutate` to the value the operand should now hold, or nil if it has not changed. Always return `result`
    func mutatingEvaluate(_ params: CallValues) -> (mutate: Optional<TemplateData>, result: TemplateData)
}

public extension MutatingMethod {
    /// Mutating methods are inherently always variant
    static var invariant: Bool { false }
    
    /// Mutating methods will never be called with the normal `evaluate` call
    func evaluate(_ params: CallValues) -> TemplateData {
        .error(internal: "Non-mutating evaluation on mutating method") }
}

// MARK: Internal Only

internal extension Method {
    var mutating: Bool { self as? MutatingMethod != nil }
}
internal protocol MapMethod: NonMutatingMethod, Invariant {}

internal protocol BoolParam: Function {}
internal extension BoolParam { static var callSignatures: [CallParameter] { [.bool] } }

internal protocol IntParam: Function {}
internal extension IntParam { static var callSignatures: [CallParameter] { [.int] } }

internal protocol DoubleParam: Function {}
internal extension DoubleParam { static var callSignatures: [CallParameter] { [.double] } }

internal protocol StringParam: Function {}
internal extension StringParam { static var callSignature: [CallParameter] { [.string] } }

internal protocol StringStringParam: Function {}
internal extension StringStringParam { static var callSignature: [CallParameter] { [.string, .string] } }

internal protocol DictionaryParam: Function {}
internal extension DictionaryParam { static var callSignature: [CallParameter] { [.dictionary] } }

internal protocol ArrayParam: Function {}
internal extension ArrayParam { static var callSignature: [CallParameter] { [.array] } }

internal protocol CollectionsParam: Function {}
internal extension CollectionsParam { static var callSignature: [CallParameter] { [.collections] } }
