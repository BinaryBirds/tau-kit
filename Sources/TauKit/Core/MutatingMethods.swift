internal extension Entities {

    func registerMutatingMethods() {
        use(MutatingStrStrMap.append, asMethod: "append")
        use(MutatingStrToStrMap.popLast, asMethod: "popLast")
        use(MutatingArrayAnyMap.append, asMethod: "append")
        use(MutatingArrayToAnyMap.popLast, asMethod: "popLast")
    }
}

/// Mutating (String, String)
internal struct MutatingStrStrMap: MutatingMethod, StringStringParam, VoidReturn {
    func mutatingEvaluate(_ params: CallValues) -> (mutate: TemplateData?, result: TemplateData) {
        let cache = params[0].string!
        var operand = cache
        f(&operand, params[1].string!)
        return (operand != cache ? operand.templateData : nil, .trueNil)
    }
    
    static let append: Self = .init({$0.append($1)})
    
    private init(_ map: @escaping (inout String, String) -> ()) { f = map }
    private let f: (inout String, String) -> ()
}

/// Mutating (String) -> String
internal struct MutatingStrToStrMap: MutatingMethod, StringParam, StringReturn {
    func mutatingEvaluate(_ params: CallValues) -> (mutate: Optional<TemplateData>, result: TemplateData) {
        let cache = params[0].string!
        var operand = cache
        let result = f(&operand)
        return (operand != cache ? operand.templateData : .none, .string(result))
    }
    
    static let popLast: Self = .init({ $0.popLast().map{String($0)} })
    
    private init(_ map: @escaping (inout String) -> String?) { f = map }
    private let f: (inout String) -> String?
}

/// Mutating (Array) -> Any
internal struct MutatingArrayToAnyMap: MutatingMethod, ArrayParam, AnyReturn {
    func mutatingEvaluate(_ params: CallValues) -> (mutate: Optional<TemplateData>, result: TemplateData) {
        let cache = params[0].array!
        var operand = cache
        let result = f(&operand)
        return (operand != cache ? .array(operand) : .none,
                result != nil ? result! : .trueNil)
    }
    
    static let popLast: Self = .init({$0.popLast()})
    
    private init(_ map: @escaping (inout [TemplateData]) -> Optional<TemplateData>) { f = map }
    private let f: (inout [TemplateData]) -> Optional<TemplateData>
}

/// Mutating (Array, Any)
internal struct MutatingArrayAnyMap: MutatingMethod, VoidReturn {
    static var callSignature: [CallParameter] { [.array, .any] }
    
    func mutatingEvaluate(_ params: CallValues) -> (mutate: Optional<TemplateData>, result: TemplateData) {
        let cache = params[0].array!
        var operand = cache
        f(&operand, params[1])
        return (operand != cache ? .array(operand) : .none, .trueNil)
    }
    
    static let append: Self = .init({$0.append($1)})
    
    private init(_ map: @escaping (inout [TemplateData], TemplateData) -> ()) { f = map }
    private let f: (inout [TemplateData], TemplateData) -> ()
}
