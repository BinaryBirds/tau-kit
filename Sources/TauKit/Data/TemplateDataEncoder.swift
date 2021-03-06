import Foundation

internal class TemplateDataEncoder: TemplateDataRepresentable, Encoder {
    
    var codingPath: [CodingKey]
    let softFail: Bool
    fileprivate unowned var parent: TemplateDataEncoder?
    private var root: TemplateDataEncoder?

    init(_ codingPath: [CodingKey] = [], _ softFail: Bool = true, _ parent: TemplateDataEncoder? = nil) {
        self.codingPath = codingPath
        self.softFail = softFail
        self.root = nil
        self.parent = parent
    }
    
    var templateData: TemplateData {
        root?.templateData ?? err
    }
    
    var err: TemplateData {
        softFail ? .trueNil : .error("No Encodable Data", function: "TemplateDataEncoder")
    }
    
    func container<K>(keyedBy type: K.Type) -> KeyedEncodingContainer<K> where K : CodingKey {
        root = KeyedTemplateDataEncoder<K>(codingPath, softFail, self)
        return .init(root as! KeyedTemplateDataEncoder<K>)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        root = UnkeyedTemplateDataEncoder(codingPath, softFail, self)
        return root as! UnkeyedTemplateDataEncoder
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        root = AtomicTemplateDataEncoder(codingPath, softFail, self)
        return root as! AtomicTemplateDataEncoder
    }
    
    /// Ignored
    var userInfo: [CodingUserInfoKey : Any] {[:]}
    
    @inline(__always)
    func _encode<T>(_ value: T) throws -> TemplateData where T: Encodable {
        if let v = value as? TemplateDataRepresentable {
            return state(v.templateData)
        }
        let e = TemplateDataEncoder(codingPath, softFail, self)
        try value.encode(to: e)
        return state(e.templateData)
    }
    
    @inline(__always)
    func state(_ value: TemplateData) -> TemplateData {
        value.errored && softFail ? .trueNil : value
    }
}

fileprivate final class AtomicTemplateDataEncoder: TemplateDataEncoder, SingleValueEncodingContainer {

    lazy var container: TemplateData = err
    override var templateData: TemplateData { container }
    
    func encodeNil() throws {
        container = .trueNil
    }
    
    func encode<T>(_ value: T) throws where T: Encodable {
        container = try _encode(value)
    }
}

fileprivate final class UnkeyedTemplateDataEncoder: TemplateDataEncoder, UnkeyedEncodingContainer {

    var array: [TemplateDataRepresentable] = []
    var count: Int { array.count }
    
    override var templateData: TemplateData {
        .array(array.map {$0.templateData})
    }
    
    func encodeNil() throws {
        array.append(TemplateData.trueNil)
    }

    func encode<T>(_ value: T) throws where T : Encodable {
        try array.append(_encode(value))
    }
    
    func nestedContainer<K>(keyedBy keyType: K.Type) -> KeyedEncodingContainer<K> where K: CodingKey {
        let c = KeyedTemplateDataEncoder<K>(codingPath, softFail, self)
        array.append(c)
        return .init(c)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let c = UnkeyedTemplateDataEncoder(codingPath, softFail, self)
        array.append(c)
        return c
    }
    
    func superEncoder() -> Encoder {
        let c = TemplateDataEncoder(codingPath, softFail, self)
        array.append(c)
        return c
    }
}

fileprivate final class KeyedTemplateDataEncoder<K>: TemplateDataEncoder, KeyedEncodingContainerProtocol where K: CodingKey {
    
    var dictionary: [String: TemplateDataRepresentable] = [:]
    var count: Int { dictionary.count }
    
    override var templateData: TemplateData {
        .dictionary(dictionary.mapValues {$0.templateData})
    }
    
    func encodeNil(forKey key: K) throws {
        dictionary[key.stringValue] = TemplateData.trueNil
    }
    
    func encodeIfPresent<T>(_ value: T?, forKey key: K) throws where T : Encodable {
        dictionary[key.stringValue] = try value.map { try _encode($0) }
    }
    
    func encode<T>(_ value: T, forKey key: K) throws where T : Encodable {
        dictionary[key.stringValue] = try _encode(value)
    }
    
    func nestedContainer<NK>(keyedBy keyType: NK.Type, forKey key: K) -> KeyedEncodingContainer<NK> where NK: CodingKey {
        let c = KeyedTemplateDataEncoder<NK>(codingPath, softFail, self)
        dictionary[key.stringValue] = c
        return .init(c)
    }
    
    func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        let c = UnkeyedTemplateDataEncoder(codingPath, softFail, self)
        dictionary[key.stringValue] = c
        return c
    }
    
    func superEncoder() -> Encoder {
        return parent!
    }

    func superEncoder(forKey key: K) -> Encoder {
        let c = TemplateDataEncoder(codingPath, softFail, self)
        dictionary[key.stringValue] = c
        return c
    }
}
