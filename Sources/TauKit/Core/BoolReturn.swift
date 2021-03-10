internal extension Entities {
    func registerBoolReturns() {
        use(StrStrToBoolMap.hasPrefix , asMethod: "hasPrefix")
        use(StrStrToBoolMap.hasSuffix , asMethod: "hasSuffix")
        
        use(CollectionToBoolMap.isEmpty , asMethod: "isEmpty")
        use(StrToBoolMap.isEmpty        , asMethod: "isEmpty")
        
        use(CollectionElementToBoolMap.contains , asMethod: "contains")
        use(StrStrToBoolMap.contains            , asMethod: "contains")
    }
}

/// (Array || Dictionary.values) -> Bool
internal struct CollectionToBoolMap: MapMethod, CollectionsParam, BoolReturn {
    func evaluate(_ params: CallValues) -> TemplateData {
        switch params[0].container {
            case .dictionary(let x) : return .bool(f(.init(x.values)))
            case .array(let x)      : return .bool(f(.init(x)))
            default                 : return .error(internal: "Only supports collections") }
    }
    
    static let isEmpty: Self = .init({ $0.isEmpty })
    
    private init(_ map: @escaping (AnyCollection<TemplateData>) -> Bool) { f = map }
    private let f: (AnyCollection<TemplateData>) -> Bool
}

/// (Array | Dictionary, Any) -> Bool
internal struct CollectionElementToBoolMap: MapMethod, BoolReturn {
    static var callSignature: [CallParameter] { [.collections, .any] }
    
    func evaluate(_ params: CallValues) -> TemplateData {
        switch params[0].container {
            case .dictionary(let x) : return .bool(f(.init(x.values), params[1]))
            case .array(let x)      : return .bool(f(.init(x), params[1]))
            default                 : return .error(internal: "Only supports collections") }
    }
    
    static let contains: Self = .init({for x in $0 where x.storedType == $1.storedType {if x == $1 { return true }}; return false})
    
    private init(_ map: @escaping (AnyCollection<TemplateData>, TemplateData) -> Bool) { f = map }
    private let f: (AnyCollection<TemplateData>, TemplateData) -> Bool
}

/// (String, String) -> Bool
internal struct StrStrToBoolMap: MapMethod, StringStringParam, BoolReturn {
    func evaluate(_ params: CallValues) -> TemplateData { .bool(f(params[0].string!, params[1].string!)) }
    
    static let hasPrefix: Self = .init({ $0.hasPrefix($1) })
    static let hasSuffix: Self = .init({ $0.hasSuffix($1) })
    static let contains: Self = .init({ $0.contains($1) })
    
    private init(_ map: @escaping (String, String) -> Bool) { f = map }
    private let f: (String, String) -> Bool
    
}

/// (String) -> Bool
internal struct StrToBoolMap: MapMethod, StringParam, BoolReturn {
    func evaluate(_ params: CallValues) -> TemplateData { .bool(f(params[0].string!)) }
    
    static let isEmpty: Self = .init({ $0.isEmpty })
    
    private init(_ map: @escaping (String) -> Bool) { f = map }
    private let f: (String) -> Bool
}
