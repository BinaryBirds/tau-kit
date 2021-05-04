// MARK: Subject to change prior to 1.0.0 release
// MARK: -
import Foundation

internal final class Serializer {
    // MARK: Stored Properties
    let ast: AST
    private(set) var error: TemplateError? = nil
        
    private var threshold: Double
    private var start: Double
    private var lapTime: Double
    private var duration: Double = 0
    private var tickCount: UInt8 = 0
            
    private var context: VariableStack
    private var contextDepth: Int = 0

    private var stack: ContiguousArray<ScopeState> = []
    private var stackDepth: Int = 0
    
    private var bufferStack: [UnsafeMutablePointer<RawBlock>] = []
    
    private var idCache: [String: Variable] = [:]
    
    private let allowUnsafe: Bool
    
    // MARK: Computed Properties

    init(_ ast: AST,
         _ context: TemplateRenderer.Context,
         _ output: RawBlock.Type) {
        self.ast = ast
        self.start = Date.distantFuture.timeIntervalSinceReferenceDate
        self.lapTime = Date.distantPast.timeIntervalSinceReferenceDate
        self.threshold = context.timeout
        self.allowUnsafe = context.grantUnsafeEntityAccess
        self.context = .init(context: context, stack: [])
        self.context.stack.reserveCapacity(Int(ast.info.stackDepths.overallMax))
        self.context.stack.append(([], VariableTablePointer.allocate(capacity: 1)))
        self.bufferStack.append(UnsafeMutablePointer<RawBlock>.allocate(capacity: 1))
        self.bufferStack[0].initialize(to: output.instantiate(size: ast.info.touch.sizeAvg,
                                                              encoding: context.encoding))
        self.stack = .init(repeating: .init(bufferStack[0]),
                           count: Int(ast.info.stackDepths.overallMax))
        self.stack[0].allocated = true
        vars.initialize(to: [:])
    }

    deinit {
        while !context.stack.isEmpty {
            let last = context.stack.removeLast().vars
            last.deinitialize(count: 1)
            last.deallocate()
        }
        bufferStack[0].deinitialize(count: 1)
        bufferStack[0].deallocate()
    }

    func serialize(_ output: inout RawBlock,
                   _ timeout: Double? = nil,
                   _ resume: Bool = false) -> Result<Double, TemplateError> {
        if resume { error = nil }
        guard !ast.scopes[0].isEmpty else { return .success(0) }
        if let timeout = timeout { threshold = timeout }
        start = Date.timeIntervalSinceReferenceDate
        lapTime = Date.distantPast.timeIntervalSinceReferenceDate
        serialize:
        while !cutoff, error == nil, !stack.isEmpty {
            /// At start of a scope block, evaluate the scope. Terminate if it
            /// can't evaluate, elide if scope is discard and continue to next
            if table > 0, offset == 0 {
                if count ?? 0 > 0 { guard reEvaluateScope() else { continue } }
                else {
                    guard let run = block != nil ? evaluateScope() : true else { break }
                    guard run else { continue }
                }
            /// Special case for atomic scopes - fully evaluate an "atomic" scope
            /// Only passthrough and raw are valid atomic scopes
            } else if table < 0 {
                /// Run repeated nils
                while count == nil {
                    guard let run = block != nil ? evaluateScope() : true else { break serialize }
                    guard run else { continue serialize }
                    switch ast.scopes[(table * -1) - 1][offset].container {
                        case .passthrough(let param): append(param.evaluate(&context))
                        case .raw(var raw):
                            append(&raw)
                            buffer.pointee.close()
                            buffer.pointee.voidAction()
                        default: __MajorBug("Non-atomic atomic scope")
                    }
                    if cutoff { break serialize }
                }
                /// Run non-nils
                while count! > 0, !cutoff {
                    guard reEvaluateScope() else { continue serialize }
                    switch ast.scopes[(-1 * table) - 1][offset].container {
                        case .passthrough(let param): append(param.evaluate(&context))
                        case .raw(var raw):
                            append(&raw)
                            buffer.pointee.close()
                            buffer.pointee.voidAction()
                        default: __MajorBug("Non-atomic atomic scope")
                    }
                }
                if cutoff && count! > 0 { break serialize }
                buffer.pointee.close()
                buffer.pointee.voidAction()
                advance()
                closeScope()
                continue
            }

            let next = peek
            if next == nil && stackDepth == 0 { break }
            switch next?.container {
                // Basic cases. Append evaluated atomics/raws to the current buffer
                case .raw(var raw)           : append(&raw)
                case .passthrough(.expression(let exp)) where exp.form.exp == .assignment:
                    buffer.pointee.voidAction()
                    switch exp.evalAssignment(&context) {
                        case .success(let val): assignValue(val.0, val.1)
                        case .failure(let err): return .failure(err)
                    }
                case .passthrough(.expression(let exp)):
                    if let x = exp.declaresVariable, x.set == nil {
                        buffer.pointee.voidAction()
                        if !allocated {
                            allocated = true
                            contextDepth += 1
                            context.stack.append(([], .allocate(capacity: 1)))
                            vars.initialize(to: .init())
                            vars.pointee[x.variable] = .trueNil
                        }
                        context.stack[contextDepth].ids.insert(x.variable.member!)
                        assignValue(x.variable, x.set?.evaluate(&context) ?? .trueNil)
                    } else { append(exp.evaluate(&context)) }
                case .passthrough(let param) :
                    append(param.evaluate(&context))
                // Blocks
                case .block(_, let b, let p):
                    var elideVoidAction = false
                    /// Handle meta first
                    if let meta = b as? MetaBlock {
                        elideVoidAction = true
                        switch meta.form {
                            case .inline    :
                                let inline = meta as! Inline
                                /// If inline type is `template`, elide - scope block dictates action
                                guard !inline.process else { break }
                                guard var raw: RawBlock = ast.raws[inline.file] else {
                                    return .failure(err(.missingRaw(inline.file))) }
                                guard let rawBlockType = TemplateConfiguration.entities.rawFactories[inline.rawIdentifier!] else {
                                    return .failure(err(.unknownError("No such raw block type for `\(inline.rawIdentifier!)`"))) }
                                var rawBlock = rawBlockType.instantiate(size: raw.byteCount, encoding: context.context.encoding)
                                rawBlock.append(&raw)
                                if let e = rawBlock.error {
                                    return .failure((e as? TemplateError) ?? err(e.localizedDescription)) }
                                buffer.pointee.append(&rawBlock)
                                advance(by: 2)
                                continue serialize
                            case .rawSwitch :
                                /// Until raw Blocks are added, non-op - raw stack will always be ByteBuffer
                                break
                            case .define    :
                                buffer.pointee.voidAction()
                                /// Push the scope pointer into the current stack's defines and skip next syntax
                                let define = meta as! Define
                                let id = define.identifier
                                let set: Bool
                                /// If define body is nil, unset if defines exists
                                if case .keyword(.nil) = define.param?.container
                                { set = false } else { set = true }
                                stack[stackDepth].defines[id] = set ? define : nil
                                /// If define is param-evaluable, push identifier into variable stack with a lazy calculator
                                if let param = define.param {
                                    if !allocated {
                                        allocated = true
                                        contextDepth += 1
                                        context.stack.append(([], .allocate(capacity: 1)))
                                        vars.initialize(to: .init())
                                    }
                                    vars.pointee[.define(id)] = set ? .init(.evaluate(param: param.container)) : nil
                                }
                                advance(by: 2)
                                continue serialize
                            case .evaluate :
                                let evaluate = meta as! Evaluate
                                advance(by: 2)
                                /// If the definition exists, open a new stack and point it at the ref scope or atomic defintion
                                if let jump = defines[evaluate.identifier] {
                                    let land = ast.scopes[jump.table][jump.row]
                                    let t = land.table * (land.table > 0 ? 1 : jump.table + 1)
                                    let o = t > 0 ? 0 : jump.row
                                    if t != 0 { newScope(from: evaluate, p: nil, t: t, o: o) }
                                /// or if no definition but evaluate has a default value roll back one and serialize that
                                } else if evaluate.defaultValue != nil { advance(by: -1) }
                                continue serialize
                            case .declare : __Unreachable("Declare rewrites to expression")
                        }
                    }
                    
                    if !elideVoidAction { buffer.pointee.voidAction() }
                    /// Otherwise actual scopes: Next check if a chained block and not at end of scope.
                    if let chained = b as? ChainedBlock {
                        if breakChain == true {
                            advance(by: 2)
                            if !nextMatchesChain(type(of: chained)) { breakChain = nil }
                            continue serialize
                        } else if breakChain == nil { breakChain = false }
                    }
                    
                    /// Cache the current table/offset for ref if an atomic scope
                    /// Signal atomic scopes with -(table + 1) value & the atomic syntax
                    /// Jump over scope block regardless
                    /// t positive table ref if actual scope table and negative offset by one to atomic scope
                    /// o is 0 if actual scope table and pointer to `syntax` if atomic scope
                    /// t == 0 is a nil scope - elide.
                    advance()
                    let t = scope[offset].table * (scope[offset].table > 0 ? 1 : table + 1)
                    let o = t > 0 ? 0 : offset
                    advance()
                    if t != 0 { newScope(from: b, p: p, t: t, o: o) }
                    continue serialize
                /// Evaluate scope, handle as necessary
                case .scope: __Unreachable("Evaluation fail - should never hit scope")
                /// Not in the top level scope and hit the end of the table but not done - repeat
                case .none where count != 0:
                    buffer.pointee.close()
                    buffer.pointee.voidAction()
                    stack[stackDepth].offset = 0
                    continue serialize
                /// Done with current scope
                case .none:
                    buffer.pointee.close()
                    buffer.pointee.voidAction()
                    closeScope()
                    continue serialize
            }
            advance()
        }
        
        if error != nil { return .failure(error!) }
        
        stack.removeAll()
        buffer.pointee.close()
        output = self.bufferStack[0].pointee
        return .success(Date.timeIntervalSinceReferenceDate - start + duration)
    }

    /// Structure holding state objects for the current scope on the stack
    private struct ScopeState {
        /// Repetition count from block.evalCount - always 0 for the top level scope
        var count: UInt32?// = nil
        /// Current scope's table in the AST
        var table: Int// = 0
        /// Current index in the current table
        var offset: Int// = 0
        var block: Block?// = nil
        var breakChain: Bool?// = nil
        var allocated: Bool// = false
        var buffer: UnsafeMutablePointer<RawBlock>
        var tuple: Tuple?// = .init()
        var defines: [String: Define]// = [:]
        var blockCreatedIDs: Set<String>?

        init(_ buffer: UnsafeMutablePointer<RawBlock>) {
            self.block = nil
            self.tuple = nil
            self.buffer = buffer
            self.defines = [:]
            self.count = nil
            self.table = 0
            self.offset = 0
            self.breakChain = nil
            self.allocated = false
            self.blockCreatedIDs = nil
        }

        init(from: Self, _ block: Block, _ tuple: Tuple?) {
            self.block = block
            self.tuple = tuple
            self.buffer = from.buffer
            self.defines = from.defines
            self.count = nil
            self.table = 0
            self.offset = 0
            self.breakChain = nil
            self.allocated = false
            self.blockCreatedIDs = nil
        }
        
        mutating func set(from: Self, _ block: Block, _ tuple: Tuple?) {
            self.block = block
            self.tuple = tuple
            self.buffer = from.buffer
            self.defines.removeAll(keepingCapacity: true)
            self.defines = from.defines
            self.count = nil
            self.table = 0
            self.offset = 0
            self.breakChain = nil
            self.allocated = false
        }
    }
}

// MARK: - Scope Handling
private extension Serializer {
    @inline(__always) func newScope(from block: Block,
                                    p params: Tuple?,
                                    t table: Int,
                                    o offset: Int) {
        var b: Block
        if var unsafeBlock = block as? UnsafeEntity, allowUnsafe {
            unsafeBlock.unsafeObjects = unsafe
            b = unsafeBlock as! Block
        } else { b = block}
        stackDepth += 1
        if stack.count == stackDepth {
            stack.append(.init(from: stack[stackDepth - 1], b, params)) }
        else {
            stack[stackDepth].set(from: stack[stackDepth - 1], b, params) }
        stack[stackDepth].table = table
        stack[stackDepth].offset = offset
        if b.scopeVariables?.isEmpty == false {
            let ids = b.scopeVariables!.compactMap { x -> String? in
                if x.isValidIdentifier { idCache[x] = .atomic(x) }
                return x.isValidIdentifier ? x : nil
            }
            if !ids.isEmpty {
                allocated = true
                blockCreatedIDs = .init(ids)
                contextDepth += 1
                context.stack.append((.init(ids), .allocate(capacity: 1)))
                vars.initialize(to: .init(minimumCapacity: ids.count))
            } else { blockCreatedIDs = nil }
        }
    }
    
    @inline(__always) func closeScope() {
        if allocated, let x = context.stack.popLast()?.vars {
            x.deinitialize(count: 1); x.deallocate(); contextDepth -= 1 }
        stackDepth -= 1
        // Reset breakChain if we were at end of chain
        if let chained = stack[stackDepth + 1].block as? ChainedBlock,
           !nextMatchesChain(type(of: chained)) {
            stack[stackDepth].breakChain = nil
        }
    }
    
    @inline(__always) func nextMatchesChain(_ antecedent: ChainedBlock.Type) -> Bool {
        guard stack[stackDepth].breakChain != nil,
              case .block(_, let n as ChainedBlock, _) = peek?.container,
              type(of: n).chainsTo.contains(where: {$0 == antecedent}) else { return false }
        return true
    }
    
    @inline(__always) func evaluateScope() -> Bool? {
        if table * offset < 1 {
            /// All metablocks will always run only once and do not produce variables; can be elided
            if block as? MetaBlock != nil { count = 0; return true }
            var t = tuple
            if let indices = t?.values.indices {
                for i in indices {
                    if !t!.values[i].isLiteral {
                        let evaluated = t!.values[i].evaluate(&context)
                        if let e = evaluated.error { void(err(e)); return nil }
                        t!.values[i] = .value(evaluated)
                    }
                }
            }
            
            guard let params = CallValues(block!.sig, t, &context) else {
                void(err("Couldn't evaluate scope parameters")); return nil }
            
            var scopeVariables: [String: TemplateData] = [:]
            let scopeValue = stack[stackDepth].block!.evaluateScope(params, &scopeVariables)
            /// if evaluate to discard, stop immediately and end the current block
            if scopeValue == 0 { closeScope(); return false }

            /// If this is a chained block, we've hit - set breakChain at the previous stack depth
            if block as? ChainedBlock != nil { stack[stackDepth - 1].breakChain = true }
            
            coalesceVariables(scopeVariables)
            count = scopeValue != nil ? scopeValue! - 1 : nil
        }
        return true
    }

    @inline(__always) func reEvaluateScope() -> Bool {
        var scopeVariables: [String: TemplateData] = [:]
        let scopeValue = stack[stackDepth].block!.reEvaluateScope(&scopeVariables)
        /// if evaluate to discard, stop immediately and end the current block
        guard let toGo = scopeValue else {
            error = err("Blocks must not return nil evaluation after having reported a concrete count")
            return false
        }
        if toGo <= 0 { closeScope(); return false }
        coalesceVariables(scopeVariables)
        count = toGo - 1
        return true
    }
}

// MARK: - Variable Handling
private extension Serializer {
    /// Has to be used with atomic, unscoped
    @inline(__always)
    func assignValue(_ key: Variable, _ value: TemplateData) {
        var depth = context.stack.count - 1
        let root = key.member!
        while depth >= 0 {
            if context.stack[depth].ids.contains(root) {
                /// Value was already set and is a dictionary
                if let original = context.stack[depth].vars.pointee[key],
                   !original.errored, original.storedType == .dictionary {
                    context.stack[depth].vars.dropDescendents(of: key)
                }
                context.stack[depth].vars.pointee[key] = value
                // FIXME: setting pathed entires does not cascade up to the root
                return
            } else { depth -= 1 }
        }
        /// If we didn't get a hit on uncontextualized but we're assigning value, it means we need to overload implicit self access
        context.stack[0].vars.pointee[key] = value
        let parent = key.contextualized
        for k in context.stack[0].vars.pointee.keys where k.isDescendent(of: parent) {
            context.stack[0].vars.pointee[k.uncontextualized] = .trueNil
        }
    }
    
    @inline(__always)
    func coalesceVariables(_ new: [String: TemplateData]) {
        guard let vars = blockCreatedIDs?.intersection(new.keys)
                                         .compactMap({idCache[$0]}),
              !vars.isEmpty else { return }
        vars.forEach { context.update($0, new[$0.member!]!) }
    }
}

// MARK: - Serialize Output Handling
private extension Serializer {
    @inline(__always) func append(_ block: inout RawBlock) {
        buffer.pointee.append(&block)
        if let e = buffer.pointee.error { void((e as? TemplateError) ?? err("Serialize Error: \(e)")) }
    }
    
    @inline(__always) func append(_ data: TemplateData) {
        if data.errored { error = err(.unknownError(data.error!)); return }
        if data.storedType == .void { stack[stackDepth].buffer.pointee.voidAction() }
        else { stack[stackDepth].buffer.pointee.append(data) }
    }
}

// MARK: - Erroring
private extension Serializer {
    @inline(__always) func lap() { lapTime = Date().timeIntervalSinceReferenceDate }
    
    @inline(__always) var cutoff: Bool {
        tickCount &+= 1
        if tickCount == 0 { lap() }
        if threshold < (lapTime - start) {
            duration += lapTime - start
            error = err(.timeout(duration))
        }
        return error != nil
    }
    
    func bool(_ error: TemplateError) -> Bool { self.error = error; return false }
    func void(_ error: TemplateError) { self.error = error }
}

// MARK: - Computed Property Conveniences
/// Note - these are conveniences - most explicitly do not have setters to avoid overhead of get/set copying
private extension Serializer {
    @inline(__always) var table: Int { stack[stackDepth].table }
    @inline(__always) var scope: ContiguousArray<Syntax> { ast.scopes[table] }
    @inline(__always) var defines: [String: Define] { stack[stackDepth].defines }
    @inline(__always) var breakChain: Bool? {
        get { stack[stackDepth].breakChain }
        set { stack[stackDepth].breakChain = newValue } }
    @inline(__always) var scopeIDs: Set<String> { context.stack[contextDepth].ids }
    @inline(__always) var blockCreatedIDs: Set<String>? {
        get { stack[stackDepth].blockCreatedIDs }
        set { stack[stackDepth].blockCreatedIDs = newValue } }
    @inline(__always) var vars: VariableTablePointer { context.stack[contextDepth].vars }
    @inline(__always) var unsafe: UnsafeObjects { context.context.unsafeObjects }
    @inline(__always) var allocated: Bool {
        get { stack[stackDepth].allocated }
        set { stack[stackDepth].allocated = newValue} }
    @inline(__always) var count: UInt32? {
        get {stack[stackDepth].count}
        set { stack[stackDepth].count = newValue } }
    @inline(__always) var block: Block? { stack[stackDepth].block }
    @inline(__always) var tuple: Tuple? { stack[stackDepth].tuple }
    @inline(__always) var buffer: UnsafeMutablePointer<RawBlock> { bufferStack.last! }
    @inline(__always) var offset: Int { stack[stackDepth].offset }
    @inline(__always) func advance(by offset: Int = 1) { stack[stackDepth].offset += offset }
    @inline(__always) var peek: Syntax? { scope.count > offset ? scope[offset] : nil }
}
