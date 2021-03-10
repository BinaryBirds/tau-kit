// MARK: Subject to change prior to 1.0.0 release
//

// MARK: - MetaBlock

internal extension Entities {
    func registerMetaBlocks() {
        use(RawSwitch.self , asMeta: "raw")
        use(Define.self    , asMeta: "define")
        //use(Define.self    , asMeta: "def")
        use(Evaluate.self  , asMeta: "evaluate")
        //use(Evaluate.self  , asMeta: "eval")
        use(Inline.self    , asMeta: "inline")
        use(Declare.self   , asMeta: "var")
        use(Declare.self   , asMeta: "let")
    }
}

internal protocol MetaBlock: Block { static var form: MetaForm { get } }

internal enum MetaForm: Int, Hashable {
    case rawSwitch
    case define
    case evaluate
    case inline
    case declare
}

// MARK: - Define/Evaluate/Inline/RawSwitch

/// `Define` blocks will be followed by a normal scope table reference or an atomic syntax
internal struct Define: MetaBlock, EmptyParams, VoidReturn, Invariant {
    static var form: MetaForm { .define }

    var identifier: String
    var param: Parameter?
    var table: Int
    var row: Int

    mutating func remap(offset: Int) { table += offset }
    
    static let warning = "call signature is (identifier) when a block, (identifier = evaluableParameter) when a function"
}

/// `Evaluate` blocks will be followed by either a nil scope syntax or a passthrough syntax if it has a defaulted value
internal struct Evaluate: MetaBlock, EmptyParams, AnyReturn {
    static var form: MetaForm { .evaluate }
    static var invariant: Bool { false }

    let identifier: String
    let defaultValue: Parameter?

    static let warning = "call signature is (identifier) or (identifier ?? evaluableParameter)"
}

/// `Inline` is always followed by a rawBlock with the current rawHandler state, and a nil scope syntax if processing
///
/// When resolving, if processing, inlined template's AST will be appended to the AST, `Inline` block's +2
/// scope syntax will point to the inlined file's remapped entry table.
/// If inlined file is not being processed, rawBlock will be replaced with one of the same type with the inlined
/// raw document's contents.
internal struct Inline: MetaBlock, EmptyParams, VoidReturn, Invariant {
    static var form: MetaForm { .inline }

    var file: String
    var process: Bool
    var rawIdentifier: String?
    var availableVars: Set<Variable>?
    
    static let literalWarning = "requires a string literal argument for the file"
    static let warning = "call signature is (\"file\", as: type) where type is `template`, `raw`, or a named raw handler"
}

/// `RawSwitch` either alters the current raw handler when by itself, or produces an isolated raw handling block with an attached scope
internal struct RawSwitch: MetaBlock, EmptyParams, AnyReturn, Invariant {
    static var form: MetaForm { .rawSwitch }

    init(_ factory: RawBlock.Type, _ tuple: Tuple) {
        self.factory = factory
        self.params = .init(tuple.values.map {$0.data!} , tuple.labels)
    }

    var factory: RawBlock.Type
    var params: CallValues
}

/// Variable declaration
internal struct Declare: MetaBlock, EmptyParams, VoidReturn, Invariant {
    static var form: MetaForm { .declare }
    
    let variable: Bool

    static let warning = "call signature is (identifier) or (identifier = evaluableParameter)"
}

// MARK: Default Implementations

extension MetaBlock {
    static var ParseSignatures: ParseSignatures? { __Unreachable("MetaBlock") }
    static var evaluable: Bool { false }
    
    var form: MetaForm { Self.form }
    var scopeVariables: [String]? { nil }
    
    static func instantiate(_ signature: String?,
                            _ params: [String]) throws -> Self  { __Unreachable("MetaBlock") }

    mutating func evaluateScope(_ params: CallValues,
                                   _ variables: inout [String: TemplateData]) -> EvalCount  { .once }
    mutating func reEvaluateScope(_ variables: inout [String: TemplateData]) -> EvalCount {
        __Unreachable("Metablocks only called once") }
}

