import Foundation
import NIO

public final class MemorySource: Source {
    public func file(template: String,
                     escape: Bool,
                     on eventLoop: EventLoop) -> EventLoopFuture<ByteBuffer> {
        self[template].map { succeed(ByteBufferAllocator().buffer(string: $0), on: eventLoop) }
                          ?? fail(.noTemplateExists(template), on: eventLoop)
    }
    
    public func timestamp(template: String,
                          on eventLoop: EventLoop) -> EventLoopFuture<Date> {
        lock.readWithLock { files[_name(template)]?.0 }
            .map { succeed($0, on: eventLoop) }
                ?? fail(.noTemplateExists(template), on: eventLoop)
    }
    
    public subscript(key: String) -> String? {
        get { lock.readWithLock { files[_name(key)]?.1.body } }
        set {
            let key = _name(key)
            lock.writeWithLock {
                guard let new = newValue else { files[key] = nil; return }
                files[key] = (Date(), .init(key, new))
            }
        }
    }
    
    public init() {}
    
    public var keys: Set<String> { lock.readWithLock {.init(files.keys)} }
    
    public func dropAll() { lock.writeWithLock { files.removeAll(keepingCapacity: true) } }
    
    private var lock: ReadWriteLock = .init()
    private var files: [String: (Date, RawTemplate)] = [:]

    private func _name(_ name: String) -> String {
        let addExtension = (name.lastIndex(of: ".") ?? name.startIndex) <=
                           (name.lastIndex(of: "/") ?? (name.hasPrefix("/") ? name.endIndex : name.startIndex))
        
        return "\(name.hasPrefix("/") ? "" : "/")\(name)\(addExtension ? ".\(TemplateSources.defaultExtension)" : "")"
    }
}
