// MARK: Subject to change prior to 1.0.0 release

/// An object that can introduce variables and/or scope into a template for anything within the block
///
/// Example: `#for(value in dictionary)`
public protocol Block: Function {
    /// Provide any relevant parse signatures, if the block must be provided data at parse time.
    ///
    /// Ex: `#for` needs to provide a signature for `x in y` where x is a parse parameter that sets
    /// the variable name it will provide to its scope when evaluated, and y is a call parameter that it will
    /// receive when being evaluated.
    static var ParseSignatures: ParseSignatures? { get }

    /// Generate a concrete object of this type given concrete parameters at parse time
    /// - Parameters:
    ///   - parseParams: The parameters this object requires at parse time
    static func instantiate(_ signature: String?, _ params: [String]) throws -> Self

    /// If the object can be called with function syntax via `evaluate`
    static var evaluable: Bool { get }
    
    /// The variable names an instantiated `Block` will provide to its block, if any.
    ///
    /// These must be consistent throughout calls to the block. If the block type will *never* provide
    /// variables, return nil rather than an empty array.
    var scopeVariables: [String]? { get }

    /// The actual entry point function of a `Block`
    ///
    /// - Parameters:
    ///   - params: `CallValues` holding the data corresponding to the block's call signature
    ///   - variables: Dictionary of variable values the block is setting.
    /// - Returns:
    ///    - `ScopeValue` signals whether the block should be re-evaluated; 0 if discard,
    ///       1...n if a known amount, nil if unknown how many times it will need to be re-evaluated
    ///    - `.discard` or `.once` are the predominant returns for most blocks
    ///    - `.indefinite` or `.repeating(x)` for looping blocks.
    ///    - If returning anything but `.indefinite`, further calls will go to `reEvaluateScope`
    ///
    /// If the block is setting any scope variable values, assign them to the corresponding key previously
    /// reported in `scopeVariables` - any variable keys not previously reported in that property will
    /// be ignored and not available inside the block's scope.
    mutating func evaluateScope(_ params: CallValues,
                                _ variables: inout [String: TemplateData]) -> EvalCount

    /// Re-entrant point for `Block`s that previously reported a finite scope count.
    ///
    /// If a block has previously reported a fixed number, it must continue to report a fixed number and may
    /// not return to reporting `.indefinite`. While it is not prohibited to *increase* the number of times
    /// upon re-evaluation, doing so should be done carefully. Count does not need to change in single
    /// increments.
    mutating func reEvaluateScope(_ variables: inout [String: TemplateData]) -> EvalCount
}

/// An object that can be chained to other `ChainedBlock` objects
///
/// - Ex: `#if(): #elseif(): #else: #endif`
/// When evaluating, the first block to return a non-discard state will have its scope evaluated and further
/// blocks in the chain will be immediately discarded.
public protocol ChainedBlock: Block {
    static var chainsTo: [ChainedBlock.Type] { get }
    static var chainAccepts: [ChainedBlock.Type] { get }
}

/// `EvalCount` dictates how many times a block will be evaluated
///
/// - `.discard` if immediately bypass the block's scope
/// - `.once` if only called once
/// - `.repeating(x)` if called a finite number of times
/// - `.indefinite` if number of calls is indeterminable
public typealias EvalCount = UInt32?
public extension EvalCount {
    static let discard: Self = 0
    static let once: Self = 1
    static let indefinite: Self = nil
    static func repeating(_ times: UInt32) -> Self { times }
}

/// A representation of a block's parsing parameters
public indirect enum ParseParameter: Hashable {
    /// A mapping of this position to a raw string `instantiate` will receive
    case unscopedVariable
    /// A mapping of a literal value
    case literal(String)
    /// A mapping of this position to the function signature parameters
    case callParameter
    /// A set of keywords the block accepts at this position
    case keyword(Set<Keyword>)

    /// A tuple - `(x, y)` where contents are *not* `.expression` or `.tuple`
    case tuple([Self])
    /// An expression - `(x in y)` where contents are *not* `.expression`
    case expression([Self])
}

// MARK: - Default Implementations

/// Default implementations for typical `Block`s
public extension Block {
    /// Default implementation of Function.evaluate()
    func evaluate(_ parameters: CallValues) -> TemplateData {
        if Self.evaluable { __MajorBug("Block called as a function: implement `evaluate`") }
        else { __MajorBug("Catachall default implementation for non-evaluable block") }
    }
}

public extension ChainedBlock {
    mutating func reEvaluateScope(_ variables: inout [String: TemplateData]) -> EvalCount {
        __MajorBug("ChainedBlocks are only called once") }
}
