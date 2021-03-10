internal extension Entities {

    func registerArrayReturns() {
        use(ArrayToArrayMap.indices, asMethod: "indices")
        use(DictionaryToArrayMap.keys, asMethod: "keys")
        use(DictionaryToArrayMap.values, asMethod: "values")
    }
}

internal struct ArrayToArrayMap: MapMethod, ArrayParam, ArrayReturn {
    func evaluate(_ params: CallValues) -> TemplateData { .array(f(params[0].array!)) }

    static let indices: Self = .init({$0.indices.map {$0.templateData}})
    
    private init(_ map: @escaping ([TemplateData]) -> [TemplateData]) { f = map }
    private let f: ([TemplateData]) -> [TemplateData]
}

internal struct DictionaryToArrayMap: MapMethod, DictionaryParam, ArrayReturn {
    func evaluate(_ params: CallValues) -> TemplateData { .array(f(params[0].dictionary!)) }

    static let keys: Self = .init({Array($0.keys.map {$0.templateData})})
    static let values: Self = .init({Array($0.values)})
    
    private init(_ map: @escaping ([String: TemplateData]) -> [TemplateData]) { f = map }
    private let f: ([String: TemplateData]) -> [TemplateData]
}
