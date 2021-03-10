import Foundation

internal class TemplateDataEncoder: TemplateDataRepresentable, Encoder {
    init(_ codingPath: [CodingKey] = [], _ softFail: Bool = true) {
        self.codingPath = codingPath
        self.softFail = softFail
        self.root = nil
    }
    
    var codingPath: [CodingKey]
    
    let softFail: Bool
    var TemplateData: TemplateData { root?.TemplateData ?? err }
    var err: TemplateData { softFail ? .trueNil : .error("No Encodable Data", function: "TemplateDataEncoder") }
    
    var root: TemplateDataEncoder?
    
    func container<K>(keyedBy type: K.Type) -> KeyedEncodingContainer<K> where K : CodingKey {
        root = KeyedTemplateDataEncoder<K>(codingPath, softFail)
        return .init(root as! KeyedTemplateDataEncoder<K>)
    }
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        root = UnkeyedTemplateDataEncoder(codingPath, softFail)
        return root as! UnkeyedTemplateDataEncoder
    }
    func singleValueContainer() -> SingleValueEncodingContainer {
        root = AtomicTemplateDataEncoder(codingPath, softFail)
        return root as! AtomicTemplateDataEncoder
    }
    
    /// Ignored
    var userInfo: [CodingUserInfoKey : Any] {[:]}
    
    @inline(__always)
    func _encode<T>(_ value: T) throws -> TemplateData where T: Encodable {
        if let v = value as? TemplateDataRepresentable { return state(v.TemplateData) }
        let e = TemplateDataEncoder(codingPath, softFail)
        try value.encode(to: e)
        return state(e.TemplateData)
    }
    
    @inline(__always)
    func state(_ value: TemplateData) -> TemplateData { value.errored && softFail ? .trueNil : value }
}

internal final class AtomicTemplateDataEncoder: TemplateDataEncoder, SingleValueEncodingContainer {
    lazy var container: TemplateData = err
    override var TemplateData: TemplateData { container }
    
    func encodeNil() throws { container = .trueNil }
    func encode<T>(_ value: T) throws where T: Encodable { container = try _encode(value) }
}

internal final class UnkeyedTemplateDataEncoder: TemplateDataEncoder, UnkeyedEncodingContainer {
    var array: [TemplateDataRepresentable] = []
    var count: Int { array.count }
    
    override var TemplateData: TemplateData { .array(array.map {$0.TemplateData}) }
    
    func encodeNil() throws { array.append(TauKit.TemplateData.trueNil) }
    func encode<T>(_ value: T) throws where T : Encodable { try array.append(_encode(value)) }
    
    func nestedContainer<K>(keyedBy keyType: K.Type) -> KeyedEncodingContainer<K> where K: CodingKey {
        let c = KeyedTemplateDataEncoder<K>(codingPath, softFail)
        array.append(c)
        return .init(c)
    }
    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let c = UnkeyedTemplateDataEncoder(codingPath, softFail)
        array.append(c)
        return c
    }
    
    func superEncoder() -> Encoder { fatalError() }
}

internal final class KeyedTemplateDataEncoder<K>: TemplateDataEncoder,
                                        KeyedEncodingContainerProtocol where K: CodingKey {
    var dictionary: [String: TemplateDataRepresentable] = [:]
    var count: Int { dictionary.count }
    
    override var TemplateData: TemplateData { .dictionary(dictionary.mapValues {$0.TemplateData}) }
    
    func encodeNil(forKey key: K) throws { dictionary[key.stringValue] = TauKit.TemplateData.trueNil }
    func encodeIfPresent<T>(_ value: T?, forKey key: K) throws where T : Encodable {
        dictionary[key.stringValue] = try value.map { try _encode($0) } }
    func encode<T>(_ value: T, forKey key: K) throws where T : Encodable {
        dictionary[key.stringValue] = try _encode(value) }
    
    func nestedContainer<NK>(keyedBy keyType: NK.Type, forKey key: K) -> KeyedEncodingContainer<NK> where NK: CodingKey {
        let c = KeyedTemplateDataEncoder<NK>(codingPath, softFail)
        dictionary[key.stringValue] = c
        return .init(c)
    }
    func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        let c = UnkeyedTemplateDataEncoder(codingPath, softFail)
        dictionary[key.stringValue] = c
        return c
    }
    
    func superEncoder() -> Encoder { fatalError() }
    func superEncoder(forKey key: K) -> Encoder { fatalError() }
}
