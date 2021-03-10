extension Entities {
    func registerTypeCasts() {
        use(Double.self, asType: "Double", storeAs: .double)
        use(Int.self, asType: "Int", storeAs: .int)
        use(Bool.self, asType: "Bool", storeAs: .bool)
        use(String.self, asType: "String", storeAs: .string)
        use([TemplateData].self, asType: "Array", storeAs: .array)
        use([String: TemplateData].self, asType: "Dictionary", storeAs: .dictionary)
        
        /// See `TemplateData`
        use(SelfMethod(), asMethod: "type")
        use(SelfFunction(), asFunction: "type")
    }
}

internal protocol TypeCast: MapMethod {}
internal extension TypeCast { func evaluate(_ params: CallValues) -> TemplateData { params[0] } }

internal struct BoolIdentity: TypeCast, BoolReturn {
    static var callSignature: [CallParameter] { [.bool] } }
internal struct IntIdentity: TypeCast, IntReturn {
    static var callSignature: [CallParameter] { [.int] } }
internal struct DoubleIdentity: TypeCast, DoubleReturn {
    static var callSignature: [CallParameter] { [.double] } }
internal struct StringIdentity: TypeCast, StringParam, StringReturn {}
internal struct ArrayIdentity: TypeCast, ArrayParam, ArrayReturn {}
internal struct DictionaryIdentity: TypeCast, DictionaryParam, DictionaryReturn {}

internal struct DataIdentity: TypeCast, DataReturn {
    static var callSignature: [CallParameter] { [.data] }
}

