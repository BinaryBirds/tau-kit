public final class Entities {
    // MARK: Internal Only Properties
    private(set) var identifiers: Set<String> = []
    private(set) var openers: Set<String> = []
    private(set) var closers: Set<String> = []
    private(set) var assignment: Set<String> = []

    /// Factories that produce `.raw` Blocks
    private(set) var rawFactories: [String: RawBlock.Type]
    /// Factories that produce named Blocks
    private(set) var blockFactories: [String: Block.Type]
    /// Function registry
    private(set) var functions: [String: [Function]]
    /// Method registry
    private(set) var methods: [String: [Method]]
    
    /// Type registery
    private(set) var types: [String: (TemplateDataRepresentable.Type, TemplateDataType)]
    
    /// Initializer
    /// - Parameter rawHandler: The default factory for `.raw` blocks
    init(rawHandler: RawBlock.Type = TemplateBuffer.self) {
        self.rawFactories = [Self.defaultRaw: rawHandler]
        self.blockFactories = [:]
        self.functions = [:]
        self.methods = [:]
        self.types = [:]
    }
    
    public static var coreEntities: Entities { ._coreEntities }
}

public extension Entities {
    // MARK: Entity Registration Methods
    
    /// Register a Block factory
    /// - Parameters:
    ///   - block: A `Block` adherent (which is not a `RawBlock` adherent)
    ///   - name: The name used to choose this factory - "name: `for`" == `#for():`
    func use(_ block: Block.Type,
             asBlock name: String) {
        if !TemplateConfiguration.running(fault: "Cannot register new Block factories") {
            name._sanity()
            block.callSignature._sanity()
            if let parseSigs = block.ParseSignatures { parseSigs._sanity() }
            precondition(block == RawSwitch.self ||
                         block as? RawBlock.Type == nil,
                         "Register RawBlock factories using `registerRaw(...)`")
            precondition(!openers.contains(name),
                         "A block named `\(name)` already exists")
            blockFactories[name] = block
            identifiers.insert(name)
            openers.insert(name)
            if let chained = block as? ChainedBlock.Type {
                precondition(chained.chainsTo.filter { $0 != block.self}
                             .allSatisfy({ b in blockFactories.values.contains(where: {$0 == b})}),
                             "All types this block chains to must be registered.")
                if chained.chainsTo.isEmpty { closers.insert("end" + name) }
                else if chained.callSignature.isEmpty { closers.insert(name) }
            } else { closers.insert("end" + name) }
        }
    }

    /// Register a Function
    /// - Parameters:
    ///   - function: An instance of a `Function` adherant which is not a mutating `Method`
    ///   - name: "name: `date`" == `#date()`
    func use(_ function: Function,
             asFunction name: String) {
        if !TemplateConfiguration.running(fault: "Cannot register new function \(name)") {
            name._sanity()
            function.sig._sanity()
            precondition(!((function as? Method)?.mutating ?? false),
                         "Mutating method \(type(of: function)) may not be used as direct functions")
            if functions.keys.contains(name) {
                functions[name]!.forEach {
                    precondition(!function.sig.confusable(with: $0.sig),
                                 "Function overload is ambiguous with \(type(of: $0))")
                }
                functions[name]!.append(function)
            } else { functions[name] = [function] }
            identifiers.insert(name)
            openers.insert(name)
        }
    }

    /// Register a Method
    /// - Parameters:
    ///   - method: An instance of a `Method` adherant
    ///   - name: "name: `hasPrefix`" == `#(a.hasPrefix(b))`
    /// - Throws: If a function for name is already registered, or name is empty
    func use(_ method: Method,
             asMethod name: String) {
        if !TemplateConfiguration.running(fault: "Cannot register new method \(name)") {
            name._sanity()
            method.sig._sanity()
            type(of: method)._sanity()
            if methods.keys.contains(name) {
                methods[name]!.forEach {
                    precondition(!method.sig.confusable(with: $0.sig),
                                 "Method overload is ambiguous with \(type(of: $0))")
                }
                methods[name]!.append(method)
            } else { methods[name] = [method] }
            identifiers.insert(name)
        }
    }

    /// Register a non-mutating `Method` as both a Function and a Method
    /// - Parameters:
    ///   - method: An instance of a `Method` adherant
    ///   - name: "name: `hasPrefix`" == `#hasPrefix(a,b)` && `#(a.hasPrefix(b)`
    /// - Throws: If a function for name is already registered, or name is empty
    func use(_ method: Method,
             asFunctionAndMethod name: String) {
        use(method, asFunction: name)
        use(method, asMethod: name)
    }
        
    /// Lightweight validator for a string that may be a template source.
    ///
    /// - Returns: True if all tag marks in the string are valid entities, but does not guarantee rendering will not error
    ///            False if there are no tag marks in the string
    ///            Nil if there are tag marks that are inherently erroring due to invalid entities.
    func validate(in string: String) -> Bool? {
        switch string.isProcessable(self) {
            case .success(true): return true
            case .success(false): return false
            case .failure: return nil
        }
    }
    
    /// Register optional entities prior to starting TauKit
    func registerExtendedEntities() {
        use(IntIntToIntMap._min, asFunction: "min")
        use(IntIntToIntMap._max, asFunction: "max")
//        use(DoubleDoubleToDoubleMap._min, asFunction: "min")
//        use(DoubleDoubleToDoubleMap._max, asFunction: "max")
        use(StrToStrMap.reversed, asMethod: "reversed")
        use(StrToStrMap.randomElement, asMethod: "randomElement")
        use(StrStrStrToStrMap.replace, asMethod: "replace")
        use(StrToStrMap.escapeHTML, asFunctionAndMethod: "escapeHTML")

        use(DoubleFormatterMap.seconds, asFunctionAndMethod: "formatSeconds")
        use(IntFormatterMap.bytes, asFunctionAndMethod: "formatBytes")
    }
}

// MARK: - Internal Only
internal extension Entities {    
    // MARK: Entity Registration Methods
    
    /// Register a type
    func use<T>(_ swiftType: T.Type,
                asType name: String,
                storeAs: TemplateDataType) where T: TemplateDataRepresentable {
        if !TemplateConfiguration.running(fault: "Cannot register new types") {
            precondition(storeAs != .void, "Void is not a valid storable type")
            precondition(!types.keys.contains(name),
                         "\(name) is already registered for \(String(describing: types[name]))")
            switch storeAs {
                case .array      : use(ArrayIdentity(), asFunction: name)
                case .bool       : use(BoolIdentity(), asFunction: name)
                case .data       : use(DataIdentity(), asFunction: name)
                case .dictionary : use(DictionaryIdentity(), asFunction: name)
                case .double     : use(DoubleIdentity(), asFunction: name)
                case .int        : use(IntIdentity(), asFunction: name)
                case .string     : use(StringIdentity(), asFunction: name)
                case .void       : __MajorBug("Void is not a valid storable type")
            }
            identifiers.insert(name)
            openers.insert(name)
        }
    }
    
    /// Register a RawBlock factory
    /// - Parameters:
    ///   - block: A `RawBlock` adherent
    ///   - name: The name used to choose this factory - "name: `html`" == `#raw(html, ....):`
    func use(_ block: RawBlock.Type,
             asRaw name: String) {
        if !TemplateConfiguration.running(fault: "Cannot register new Raw factory \(name)") {
            name._sanity()
            block.callSignature._sanity()
            precondition(!openers.contains(name),
                         "A block named `\(name)` already exists")
            rawFactories[name] = block
        }
    }
    
    /// Register a metablock
    func use(_ meta: MetaBlock.Type,
             asMeta name: String) {
        if !TemplateConfiguration.running(fault: "Cannot register new Metablock factory \(name)") {
            if meta.form != .declare { name._sanity() }
            precondition(!openers.contains(name),
                         "A block named `\(name)` already exists")
            blockFactories[name] = meta
            identifiers.insert(name)
            openers.insert(name)
            if [.define, .rawSwitch].contains(meta.form) { closers.insert("end" + name) }
            if [.define, .declare].contains(meta.form) { assignment.insert(name) }
        }
    }
    
    // MARK: Validators
    
    /// Return all valid matches.
    func validateFunction(_ name: String,
                          _ params: Tuple?) -> Result<[(Function, Tuple?)], ParseErrorCause> {
        guard let functions = functions[name] else { return .failure(.noEntity(type: "function", name: name)) }
        var valid: [(Function, Tuple?)] = []
        for function in functions {
            if let tuple = try? validateTupleCall(params, function.sig).get()
            { valid.append((function, tuple.isEmpty ? nil : tuple)) } else { continue }
        }
        if !valid.isEmpty { return .success(valid) }
        return .failure(.sameName(type: "function", name: name, params: (params ?? .init()).description, matches: functions.map {$0.sig.short} ))
    }
    
    func validateMethod(_ name: String,
                        _ params: Tuple?,
                        _ mutable: Bool) -> Result<[(Function, Tuple?)], ParseErrorCause> {
        guard let methods = methods[name] else {
            return .failure(.noEntity(type: "method", name: name)) }
        var valid: [(Function, Tuple?)] = []
        var mutatingMismatch = false
        for method in methods {
            if method.mutating && !mutable { mutatingMismatch = true; continue }
            if let tuple = try? validateTupleCall(params, method.sig).get()
            { valid.append((method, tuple.isEmpty ? nil : tuple)) } else { continue }
        }
        if valid.isEmpty {
            return .failure(mutatingMismatch ? .mutatingMismatch(name: name)
                                : .sameName(type: "function", name: name, params: (params ?? .init()).description, matches: methods.map {$0.sig.short} ) )
        }
        return .success(valid)
    }

    func validateBlock(_ name: String,
                       _ params: Tuple?) -> Result<(Function, Tuple?), ParseErrorCause> {
        guard blockFactories[name] != RawSwitch.self else { return validateRaw(params) }
        guard let factory = blockFactories[name] else { return .failure(.noEntity(type: "block", name: name)) }
        let block: Function?
        var call: Tuple = .init()

        validate:
        if let parseSigs = factory.ParseSignatures {
            for (name, sig) in parseSigs {
                guard let match = sig.splitTuple(params ?? .init()) else { continue }
                guard let created = try? factory.instantiate(name, match.0) else {
                    return .failure(.parameterError(name: name, reason: "Parse signature matched but couldn't instantiate")) }
                block = created
                call = match.1
                break validate
            }
            block = nil
        } else if (params?.count ?? 0) == factory.callSignature.count {
            if let params = params { call = params }
            block = try? factory.instantiate(nil, [])
        } else { return .failure(.parameterError(name: name, reason: "Takes no parameters")) }

        guard let function = block else {
            return .failure(.parameterError(name: name, reason: "Parameters don't match parse signature") )}
        let validate = validateTupleCall(call, function.sig)
        switch validate {
            case .failure(let message): return .failure(.parameterError(name: name, reason: message))
            case .success(let tuple): return .success((function, !tuple.isEmpty ? tuple : nil))
        }
    }

    func validateRaw(_ params: Tuple?) -> Result<(Function, Tuple?), ParseErrorCause> {
        var name = Self.defaultRaw
        var call: Tuple

        if let params = params {
            if case .variable(let v) = params[0]?.container, v.isAtomic { name = String(v.member!) }
            else { return .failure(.unknownError("Specify raw handler with unquoted name")) }
            call = params
            call.values.removeFirst()
            call.labels = call.labels.mapValues { $0 - 1 }
        } else { call = .init() }

        guard let factory = rawFactories[name] else { return .failure(.unknownError("\(name) is not a raw handler"))}
        guard call.values.allSatisfy({ $0.data != nil }) else {
            return .failure(.unknownError("Raw handlers currently require literal data parameters")) }
        let validate = validateTupleCall(call, factory.callSignature)
        switch validate {
            case .failure(let message): return .failure(.parameterError(name: name, reason: message))
            case .success(let tuple): return .success((RawSwitch(factory, tuple), nil))
        }
    }

    func validateTupleCall(_ tuple: Tuple?, _ expected: [CallParameter]) -> Result<Tuple, String> {
        /// True if actual parameter matches expected parameter value type, or if actual parameter is uncertain type
        func matches(_ actual: Parameter, _ expected: CallParameter) -> Bool {
            guard let t = actual.baseType else { return true }
            if case .value(let literal) = actual.container, literal.isNil { return expected.optional }
            return expected.types.contains(t) ? true
                  : expected.types.first(where: {t.casts(to: $0) != .ambiguous}) != nil
        }
        
        func output() -> Result<Tuple, String> {
            for i in 0 ..< count.out {
                if temp[i] == nil { return .failure("Missing parameter \(expected[i].description)") }
                tuples.out.values.append(temp[i]!)
            }
            return .success(tuples.out)
        }

        guard expected.count < 256 else { return .failure("Can't have more than 255 params") }

        var tuples = (in: tuple ?? Tuple(), out: Tuple())

        /// All input must be valued types
        guard tuples.in.values.allSatisfy({$0.isValued}) else {
            return .failure("Parameters must all be value types") }

        let count = (in: tuples.in.count, out: expected.count)
        let defaults = expected.compactMap({ $0.defaultValue }).count
        /// Guard that `in.count <= out.count` && `in.count + default >= out.count`
        if count.in > count.out { return .failure("Too many parameters") }
        if Int(count.in) + defaults < count.out { return .failure("Not enough parameters") }

        /// guard that if the signature has labels, input is fully contained and in order
        let labels = (in: tuples.in.enumerated.compactMap {$0.label}, out: expected.compactMap {$0.label})
        guard labels.out.filter({labels.in.contains($0)}).elementsEqual(labels.in),
              Set(labels.out).isSuperset(of: labels.in) else { return .failure("Label mismatch") }

        var temp: [Parameter?] = .init(repeating: nil, count: expected.count)

        /// Copy all labels to out and labels and/or default values to temp
        for (i, p) in expected.enumerated() {
            if let label = p.label { tuples.out.labels[label] = i }
            if let data = p.defaultValue { temp[i] = .value(data) }
        }

        /// If input is empty, all default values are already copied and we can output
        if count.in == 0 { return output() }

        /// Map labeled input parameters to their correct position in the temp array
        for label in labels.in { temp[Int(tuples.out.labels[label]!)] = tuples.in[label] }

        /// At this point any nil value in the temp array is undefaulted, and
        /// the only values uncopied from tuple.in are unlabeled values
        var index = 0
        let last = (in: (tuples.in.labels.values.min() ?? count.in) - 1,
                    out: (tuples.out.labels.values.min() ?? count.out) - 1)
        while index <= last.in, index <= last.out {
            let param = tuples.in.values[index]
            /// apply all unlabeled input params to temp, unsetting if not matching expected
            temp[index] = matches(param, expected[index]) ? param : nil
            if temp[index] == nil { break }
            index += 1
        }
        return output()
    }
    
    /// Convenience referent to the default `.raw` Block factory
    static var defaultRaw: String { "raw" }
    var raw: RawBlock.Type { rawFactories[Self.defaultRaw]! }
}

// MARK: - Private Only
private extension Entities {
    private static var _coreEntities: Entities {
        let entities = Entities()
        
        entities.registerMetaBlocks()
        entities.registerControlFlow()
        
        entities.registerTypeCasts()
        entities.registerErroring()

        entities.registerArrayReturns()
        entities.registerBoolReturns()
        entities.registerIntReturns()
        entities.registerDoubleReturns()
        entities.registerStringReturns()
        entities.registerMutatingMethods()
        
        entities.registerTimestampAndDate()

        return entities
    }
}
