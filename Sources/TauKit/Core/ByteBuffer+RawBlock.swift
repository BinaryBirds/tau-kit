import Foundation
import NIOFoundationCompat

extension ByteBuffer: RawBlock {
    var error: Error? { nil }
    var encoding: String.Encoding { .utf8 }
    
    static var recall: Bool { false }

    static func instantiate(size: UInt32,
                            encoding: String.Encoding) -> RawBlock {
        ByteBufferAllocator().buffer(capacity: Int(size)) }

    /// Always identity return and valid
    var serialized: (buffer: ByteBuffer, valid: Bool?) { (self, true) }

    /// Always takes either the serialized view of a `RawBlock` or the direct result if it's a `ByteBuffer`
    mutating func append(_ block: inout RawBlock) {
        var input = block as? Self ?? block.serialized.buffer
        let inputEncoding = block.encoding
        
        guard encoding != inputEncoding else { writeBuffer(&input); return }
        fatalError()
    }
    
    mutating func append(_ data: TemplateData) { _append(data) }

    /// Appends data using configured serializer views
    mutating func _append(_ data: TemplateData, wrapString: Bool = false) {
        guard !data.isNil else {
            write(TemplateBuffer.nilFormatter(data.storedType.short))
            return
        }
        switch data.storedType {
            case .bool       : write(TemplateBuffer.boolFormatter(data.bool!))
            case .data       : write(TemplateBuffer.dataFormatter(data.data!, .utf8) ?? "")
            case .double     : write(TemplateBuffer.doubleFormatter(data.double!))
            case .int        : write(TemplateBuffer.intFormatter(data.int!))
            case .string     : write(TemplateBuffer.stringFormatter(wrapString ? "\"\(data.string!)\"": data.string!))
            case .void       : break
            case .array      : let a = data.array!
                               write("[")
                               for index in a.indices {
                                    _append(a[index], wrapString: true)
                                    if index != a.indices.last! { write(", ") }
                               }
                               write("]")
            case .dictionary : let d = data.dictionary!.sorted { $0.key < $1.key }
                               write("[")
                               for index in d.indices {
                                    write("\"\(d[index].key)\": ")
                                    _append(d[index].value, wrapString: true)
                                    if index != d.indices.last! { write(", ") }
                               }
                               if d.isEmpty { write(":") }
                               write("]")
        }
    }
    
    mutating func voidAction() {}
    mutating func close() {}

    var byteCount: UInt32 { UInt32(readableBytes) }
    var contents: String { getString(at: readerIndex, length: readableBytes) ?? "" }
    
    mutating func write(_ str: String) { try! writeString(str, encoding: encoding) }
}
