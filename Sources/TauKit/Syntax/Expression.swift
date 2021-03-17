import Foundation

internal struct Expression: Symbol {
    // MARK: - Internal Only
    // MARK: - Generators

    /// Generate an Expression from a 2-3 value parameters that is internally resolvable
    static func express(_ params: [Parameter]) -> Self? { Self(params) }
    /// Generate an Expression from a 3 value ternary conditional
    static func expressTernary(_ params: [Parameter]) -> Self? { Self(ternary: params) }
    /// Generate a custom Expression from any 2-3 value parameters, regardless of grammar
    static func expressAny(_ params: [Parameter]) -> Self? { Self(custom: params) }

    // MARK: - Symbol Conformance
    private(set) var resolved: Bool
    private(set) var invariant: Bool
    private(set) var symbols: Set<Variable>

    private(set) var baseType: TemplateDataType?

    func resolve(_ symbols: inout VariableStack) -> Self {
        form.exp != .ternary
            ? .init(.init(storage.map { $0.resolve(&symbols) }), form)
            : .init(.init([storage[0].resolve(&symbols), storage[1], storage[2]]), form)
    }

    func evaluate(_ symbols: inout VariableStack) -> TemplateData {
        switch form.exp {
            case .calculation : break
            case .ternary     : return evalTernary(&symbols)
            case .assignment  : __MajorBug("Assignment should have redirected")
            case .custom      :
                if case .keyword(let k) = first.container,
                   k.isVariableDeclaration { return createVariable(&symbols) }
                __MajorBug("Custom expression produced in AST")
        }
        
        switch form.op! {
            case .infix        : return evalInfix(lhs!.evaluate(&symbols), op!, rhs!.evaluate(&symbols))
            case .unaryPrefix  : return evalPrefix(op!, rhs!.evaluate(&symbols))
            case .unaryPostfix : return evalPostfix(lhs!.evaluate(&symbols), op!)
        }
    }

    /// Short String description: `lhs op rhs` for assignment/calc, `first second third?` for custom
    var short: String {
        switch form.exp {
            case .assignment,
                 .calculation: return "[\([lhs?.short ?? "", op?.short ?? "", rhs?.short ?? ""].filter{ !$0.isEmpty }.joined(separator: " "))]"
            case .ternary: return "[\(storage[0].short) ? \(storage[1].short) : \(storage[2].short)]"
            case .custom: return "[\(storage.compactMap { $0.operator != .subOpen ? $0.short : nil }.joined(separator: " "))]"
        }
    }
    /// String description: `expressionform[expression.short]`
    var description: String { "\(form.exp.short)\(short)" }

    // MARK: - Expression Specific
    /// The form expression storage takes: `[.calculation, .assignment, .ternary, .custom]`
    enum Form: String, TemplatePrintable {
        case calculation
        case assignment
        case ternary
        case custom

        var description: String  { rawValue }
        var short: String        { rawValue }
    }

    typealias CombinedForm = (exp: Expression.Form, op: Operator.Form?)
    /// Reveal the form of the expression, and of the operator when expression form is relevant
    let form: CombinedForm

    /// Convenience referent name available when form is not .custom
    var op: Operator?  { form.op == nil ? nil : form.op! == .unaryPrefix
                                                  ? storage[0].operator
                                                  : storage[1].operator }
    /// Convenience referent name available when form is not .custom
    var lhs: Parameter? { [.infix, .unaryPostfix].contains(form.op) ? storage[0] : nil }
    /// Convenience referent name available when form is not .custom
    var rhs: Parameter? { form.op == .infix ? storage[2] : form.op == .unaryPrefix ? storage[1] : nil }
    /// Convenience referent name by position within expression
    var first: Parameter   { storage[0] }
    /// Convenience referent name by position within expression
    var second: Parameter  { storage[1] }
    /// Convenience referent name by position within expression
    var third: Parameter?  { storage[2].operator != .subOpen ? storage[2] : nil }
    
    
    /// If expression declares a variable, variable so declared, and value if set
    var declaresVariable: (variable: Variable, set: Parameter?)? {
        if case .keyword(let k) = first.container, k.isVariableDeclaration,
           case .variable(let v) = second.container {
            let x: Parameter?
            if case .value(.trueNil) = third?.container { x = nil } else { x = third! }
            return (v, x)
        }
        return nil
    }

    // MARK: - Private Only
    /// Actual storage of 2 or 3 Parameters
    private var storage: ContiguousArray<Parameter> { didSet { setStates() } }

    /// Generate a `Expression` if possible. Guards for expressibility unless "custom" is true
    private init?(_ params: [Parameter]) {
        // .assignment/.calculation is failable, .custom does not check
        guard var form = Self.expressible(params) else { return nil }
        var params = params
        // Rewrite prefix minus special case into rhs * -1
        if let unary = form.op, unary == .unaryPrefix, params[0].operator == .minus {
            form = (.calculation, .infix)
            params = [params[1], .operator(.multiply), .value(.int(-1))]
        } else if params[1].operator == .nilCoalesce, case .variable(var v) = params[0].container {
            v.state.formUnion(.coalesced)
            params[0] = .variable(v)
        }
        self = .init(.init(params), form)
    }

    /// Generate a custom `Expression` if possible.
    private init?(custom: [Parameter]) {
        guard (2...3).contains(custom.count) else { return nil }
        let storage = custom.count == 3 ? custom : custom + CollectionOfOne(.invalid)
        self = .init(.init(storage), (.custom, nil))
    }

    /// Generate a ternary `Expression` if possible.
    private init?(ternary: [Parameter]) {
        guard ternary.count == 3 else { return nil }
        self = .init(.init(ternary), (.ternary, nil))
    }

    private init(_ storage: ContiguousArray<Parameter>, _ form: CombinedForm) {
        self.storage = storage
        self.form = form
        self.resolved = false
        self.invariant = false
        self.symbols = []
        switch form.exp {
            case .ternary     : self.baseType = second.baseType == third!.baseType ? second.baseType : nil
            case .assignment  : self.baseType = op == .assignment ? rhs!.baseType : lhs!.baseType
            case .calculation where ![.subScript, .nilCoalesce].contains(op) :
                self.baseType = lhs != nil ? lhs!.baseType : rhs!.baseType
            default           : self.baseType = nil
        }
        setStates()
    }

    private mutating func setStates() {
        resolved = storage.allSatisfy { $0.resolved }
        invariant = storage.allSatisfy {$0.invariant}

        if storage[1].operator == .nilCoalesce { symbols = rhs!.symbols }
        else if let declaredValue = declaresVariable?.set { symbols = declaredValue.symbols }
        else { storage.forEach { symbols.formUnion($0.symbols) } }
        
    }

    /// Return the Expression and Operator Forms if the array of Parameters forms a syntactically correct Expression
    private static func expressible(_ p: [Parameter]) -> CombinedForm? {
        let op: Operator
        let opForm: Operator.Form
        guard (2...3).contains(p.count) else { return nil }

        if p.count == 3 {
            if let o = infixExp(p[0], p[1], p[2]), o.parseable { op = o; opForm = .infix }
            else { return nil }
        } else {
            if let o = unaryPreExp(p[0], p[1]), o.parseable { op = o; opForm = .unaryPrefix }
            else if let o = unaryPostExp(p[0], p[1]), o.parseable { op = o; opForm = .unaryPostfix }
            else { return nil }
        }
        // Ignore special case of prefix minus here
        if op.mathematical || op.logical { return (.calculation, opForm) }
        else if [.subScript, .nilCoalesce].contains(op) { return (.calculation, .infix) }
        else { return (.assignment, opForm) }
    }

    /// Return the operator if the three parameters are syntactically an infix expression
    private static func infixExp(_ a: Parameter, _ b: Parameter, _ c: Parameter) -> Operator? {
        guard let op = b.operator, op.infix,
              a.operator == nil, c.operator == nil else { return nil }
        return op
    }

    /// Return the operator if the two parameters is syntactically a unaryPrefix expression
    private static func unaryPreExp(_ a: Parameter, _ b: Parameter) -> Operator? {
        guard let op = a.operator, op.unaryPrefix, b.operator == nil else { return nil}
        return op
    }

    /// Return the operator if the two parameters is syntactically a unaryPostfix expression
    private static func unaryPostExp(_ a: Parameter, _ b: Parameter) -> Operator? {
        guard let op = b.operator, op.unaryPostfix, a.operator == nil else { return nil}
        return op
    }

    /// Evaluate an infix expression
    private func evalInfix(_ lhs: TemplateData, _ op: Operator, _ rhs: TemplateData) -> TemplateData {
        if lhs.errored, ![.or, .xor, .unequal, .nilCoalesce].contains(op) { return lhs }
        if rhs.errored, ![.or, .xor, .unequal].contains(op) { return rhs }
        switch op {
            case .nilCoalesce    : return lhs.errored || lhs.isNil ? rhs : lhs
            /// Equatable conformance passthrough
            case .equal          : return .bool(lhs == rhs)
            case .unequal        : return .bool(lhs != rhs)
            /// If data is bool-representable, that value; other wise true if non-nil
            case .and, .or, .xor :
                let lhsB = lhs.bool ?? !lhs.isNil
                let rhsB = rhs.bool ?? !rhs.isNil
                if op == .and { return .bool(lhsB && rhsB) }
                if op == .xor { return .bool(lhsB != rhsB) }
                return .bool(lhsB || rhsB)
            /// Int compare when both int, Double compare when both numeric & >0 Double
            /// String compare when neither a numeric type
            case .greater, .lesserOrEqual, .lesser, .greaterOrEqual  :
                return .bool(comparisonOp(op, lhs, rhs))
            /// If both sides are numeric, use lhs to indicate return type and sum
            /// If left side is string, concatanate string
            /// If left side is data, concatanate data
            /// If both sides are collections of same type -
            ///      If array, concatenate
            ///      If dictionary and no keys overlap, concatenate
            /// Anything else fails
            case .plus           :
                if lhs.state.intersection(rhs.state).contains(.numeric) {
                    guard let numeric = numericOp(op, lhs, rhs) else { fallthrough }
                    return numeric
                } else if lhs.storedType == .string {
                    return .string(lhs.string! + (rhs.string ?? ""))
                } else if lhs.storedType == .data {
                    guard let rhsData = rhs.data else { fallthrough }
                    return .data(lhs.data! + rhsData)
                } else if lhs.isCollection && lhs.storedType == rhs.storedType {
                    if lhs.storedType == .array { return .array(lhs.array! + rhs.array!) }
                    guard let lhs = lhs.dictionary, let rhs = rhs.dictionary,
                          Set(lhs.keys).intersection(Set(rhs.keys)).isEmpty else { fallthrough }
                    return .dictionary(lhs.merging(rhs) {old, _ in old })
                } else if rhs.storedType == .string {
                    return .string((lhs.string ?? "") + rhs.string!)
                } else { return .trueNil }
            case .minus, .divide, .multiply, .modulo :
                if lhs.state.intersection(rhs.state).contains(.numeric) {
                    guard let numeric = numericOp(op, lhs, rhs) else { fallthrough }
                    return numeric
                } else { fallthrough }
            case .subScript:
                if lhs.storedType == .array, let index = rhs.int,
                   case .array(let a) = lhs.container,
                   a.indices.contains(index) { return a[index] }
                if lhs.storedType == .dictionary, let key = rhs.string,
                   case .dictionary(let d) = lhs.container { return d[key] ?? .trueNil }
                fallthrough
            default: return .trueNil
        }
    }
    
    func createVariable(_ symbols: inout VariableStack) -> TemplateData {
        if case .variable(let x) = second.container,
           let value = third?.container.evaluate(&symbols) { symbols.create(x, value) }
        return .trueNil
    }
    
    /// Evaluate assignments.
    ///
    /// If variable lookup succeeds, return variable key and value to set to; otherwise error
    func evalAssignment(_ symbols: inout VariableStack) -> Result<(Variable, TemplateData), TemplateError> {
        guard case .variable(let assignor) = first.container,
              let op = op, op.assigning,
              let value = third?.evaluate(&symbols) else {
            __MajorBug("Improper assignment expression") }
        
        if assignor.isPathed, let parent = assignor.parent,
           (symbols._match(parent)?.storedType ?? .void) != .dictionary {
            return .failure(err("\(parent.terse) is not a dictionary; cannot set \(assignor)"))
        } else if !assignor.isPathed, symbols._match(assignor) == nil {
            return .failure(err("\(assignor.terse) must be defined first with `var \(assignor.member ?? "")`"))
        }
        /// Straight assignment just requires identifier parent exists if it's pathed.
        if op == .assignment { return .success((assignor, value)) }
        
        guard let old = symbols._match(assignor) else {
            return .failure(err("\(assignor.member!) does not exist; can't perform compound assignment")) }
        
        let new: TemplateData
        switch op {
            case .compoundPlus  : new = evalInfix(old, .plus, value)
            case .compoundMinus : new = evalInfix(old, .minus, value)
            case .compoundMult  : new = evalInfix(old, .multiply, value)
            case .compoundDiv   : new = evalInfix(old, .divide, value)
            case .compoundMod   : new = evalInfix(old, .modulo, value)
            default             : __MajorBug("Unexpected operator")
        }
        return .success((assignor, new))
    }

    /// Evaluate a ternary expression
    private func evalTernary(_ symbols: inout VariableStack) -> TemplateData {
        let condition = first.evaluate(&symbols)
        if condition.errored { return condition }
        switch condition.bool {
            case .some(true),
                 .none where !condition.isNil  : return second.evaluate(&symbols)
            case .some(false),
                 .none where condition.isNil   : return third!.evaluate(&symbols)
            case .none: __Unreachable("Ternary condition returned non-bool")
        }
    }

    /// Evaluate a prefix expression
    private func evalPrefix(_ op: Operator, _ rhs: TemplateData) -> TemplateData {
        if rhs.errored { return rhs }
        switch op {
            // nil == false; ergo !nil == true
            case .not   : return .bool(!(rhs.bool ?? false))
            // raw Int & Double only - don't attempt to cast
            case .minus :
                if case .int(let i) = rhs.container { return .int(-1 * i) }
                else if case .double(let d) = rhs.container { return .double(-1 * d) }
                else { fallthrough }
            default     :  return .error(internal: "Unhandled prefix operator")
        }
    }

    /// Evaluate a postfix expression
    private func evalPostfix(_ lhs: TemplateData, _ op: Operator) -> TemplateData {
        lhs.errored ? lhs : .error(internal: "Unhandled postfix operator") }

    /// Encapsulated calculation for `>, >=, <, <=`
    /// Nil returning unless both sides are in [.int, .double] or both are string-convertible & non-nil
    private func comparisonOp(_ op: Operator, _ lhs: TemplateData, _ rhs: TemplateData) -> Bool? {
        if lhs.isCollection || rhs.isCollection || lhs.isNil || rhs.isNil { return nil }
        var op = op
        let numeric = lhs.isNumeric && rhs.isNumeric
        let manner = !numeric ? .string : lhs.storedType == rhs.storedType ? lhs.storedType : .double
        if [.greaterOrEqual, .lesserOrEqual].contains(op) {
            switch manner {
                case .int    : if lhs.int ?? 0 == rhs.int ?? 0 { return true }
                case .double : if lhs.double ?? 0.0 == rhs.double ?? 0.0 { return true }
                default      : if lhs.string ?? ""  == rhs.string ?? "" { return true }
            }
            op = op == .greaterOrEqual ? .greater : .lesser
        }
        switch op {
            case .greater:
                switch manner {
                    case .int    : return lhs.int    ?? 0   > rhs.int    ?? 0
                    case .double : return lhs.double ?? 0.0 > rhs.double ?? 0.0
                    default      : return lhs.string ?? ""  > rhs.string ?? ""
                }
            case .lesser:
                switch manner {
                    case .int    : return lhs.int    ?? 0   < rhs.int    ?? 0
                    case .double : return lhs.double ?? 0.0 < rhs.double ?? 0.0
                    default      : return lhs.string ?? ""  < rhs.string ?? ""
                }
            default: return nil
        }
    }

    /// Encapsulated calculation for `+, -, *, /, %`
    /// Nil returning unless both sides are in [.int, .double]
    private func numericOp(_ op: Operator, _ lhs: TemplateData, _ rhs: TemplateData) -> TemplateData? {
        guard lhs.state.intersection(rhs.state).contains(.numeric) else { return nil }
        if lhs.storedType == .int {
            guard let lhsI = lhs.int, let rhsI = rhs.convert(to: .int, .coercible).int else { return nil }
            let value: (partialValue: Int, overflow: Bool)
            switch op {
                case .plus     : value = lhsI.addingReportingOverflow(rhsI)
                case .minus    : value = lhsI.subtractingReportingOverflow(rhsI)
                case .multiply : value = lhsI.multipliedReportingOverflow(by: rhsI)
                case .divide   : value = lhsI.dividedReportingOverflow(by: rhsI)
                case .modulo   : value = lhsI.remainderReportingOverflow(dividingBy: rhsI)
                default        : return nil
            }
            return value.overflow ? .error(internal: "Integer overflow") : .int(value.partialValue)
        } else {
            guard let lhsD = lhs.double, let rhsD = rhs.double else { return nil }
            switch op {
                case .plus     : return .double(lhsD + rhsD)
                case .minus    : return .double(lhsD - rhsD)
                case .multiply : return .double(lhsD * rhsD)
                case .divide   : return .double(lhsD / rhsD)
                case .modulo   : return .double(lhsD.remainder(dividingBy: rhsD))
                default: return nil
            }
        }
    }
}

