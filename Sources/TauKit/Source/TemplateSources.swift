import Foundation
import NIOConcurrencyHelpers

/// An opaque object holding named `Source` adherants specifying a default search order.
///
/// This object is `public` solely for convenience in reading the currently configured state.
///
/// Once registered, the `Source` objects can not be accessed or modified - they *must* be
/// fully configured prior to registering with the instance of `Sources`
/// - `Source` objects are registered with an instance of this class - this should *only* be done
///     prior to use by `Renderer`.
/// - `.all` provides a `Set` of the `String`keys for all sources registered with the instance
/// - `.searchOrder` provides the keys of sources that an unspecified template request will search.
public final class TemplateSources {
    // MARK: - Public
    
    /// Default filesystem directory for file-based `Source` adherents provided by TauKit, if not
    /// explicitly set when instantiating a `Source`
    @RuntimeGuard public static var rootDirectory: String = "/"
    
    /// Default file extension used for implicit location of templates when no extension is provided
    @RuntimeGuard(condition: {!$0.contains(".")})
    public static var defaultExtension: String = "html"

    /// All available `Source`s of templates
    public var all: Set<String> { lock.withLock { keys } }
    /// Configured default implicit search order of `Source`'s
    public var searchOrder: [String] { lock.withLock { order } }

    public init() {
        self.keys = []
        self.order = []
        self.sources = [:]
    }

    /// Register a `Source` as `key`
    /// - Parameters:
    ///   - key: Name for the source; at most one may be registered without a name
    ///   - source: A fully configured `Source` object
    ///   - searchable: Whether the source should be added to the default search path
    /// - Throws: Attempting to overwrite a previously named source is not permitted
    public func register(source key: String = "default",
                         using source: Source,
                         searchable: Bool = true) throws {
        precondition(key.first != "$", "Source name may not start with `$`")
        precondition(!key.contains(":"), "Source name may not contain `:`")
        precondition(!keys.contains(key), "Can't replace source at \(key)")
        lock.withLock {
            keys.insert(key)
            sources[key] = source
            if searchable { order.append(key) }
        }
    }

    /// Convenience for initializing a `Sources` object with a single `Source`
    /// - Parameter source: A fully configured `Source`
    /// - Returns: Configured `Source` instance
    public static func singleSource(_ source: Source) -> TemplateSources {
        let sources = TemplateSources()
        try! sources.register(using: source)
        return sources
    }

    // MARK: - Internal/Private Only
    private(set) var sources: [String: Source]
    private var order: [String]
    private var keys: Set<String>
    private let lock: Lock = .init()

    /// Locate a template from the sources; if a specific source is named, only try to read from it.
    /// Otherwise, use the specified search order. Key (and thus AST name) are "$:template" when no source
    /// was specified, or "source:template" when specified
    func file(_ key: AST.Key, on eL: EventLoop) -> EventLoopFuture<(key: String,
                                                           buffer: ByteBuffer)> {
        let source = key._src
        let template = key._name
        if source != "$", keys.contains(source) {
            return searchSources(template, [source], on: eL)
                                .map { ("\(source):\(template)", $0.buffer) }
        } else if source == "$", !order.isEmpty {
            return searchSources(template, order, on: eL)
                                .map { ("\(source):\(template)", $0.buffer) }
        }
        return fail(source == "$" ? .noSources : .noSourceForKey(source), on: eL)
    }
    
    func timestamp(_ key: AST.Key, on eL: EventLoop) -> EventLoopFuture<Date> {
        let source = key._src
        let template = key._name
        if source != "$", keys.contains(source) {
            return searchSources(template, [source], on: eL)
        } else if source == "$", !order.isEmpty {
            return searchSources(template, order, on: eL)
        }
        return fail(source == "$" ? .noSources : .noSourceForKey(source), on: eL)
    }
    
    private func searchSources(_ t: String,
                               _ s: [String],
                               on eL: EventLoop) -> EventLoopFuture<(source: String,
                                                         buffer: ByteBuffer)> {
        if s.isEmpty { return fail(.noTemplateExists(t), on: eL) }
        var rest = s
        let key = rest.removeFirst()
        let source = lock.withLock { sources[key]! }
        
        return source.file(template: t, escape: true, on: eL)
                     .map { (source: key, buffer: $0) }
                     .flatMapError { $0.illegal ? fail($0.TemplateError!, on: eL)
                                                : self.searchSources(t, rest, on: eL) }
    }
    
    private func searchSources(_ t: String,
                               _ s: [String],
                               on eL: EventLoop) -> EventLoopFuture<Date> {
        if s.isEmpty { return fail(.noTemplateExists(t), on: eL) }
        var rest = s
        let key = rest.removeFirst()
        let source = lock.withLock { sources[key]! }
        
        return source.timestamp(template: t, on: eL)
                     .flatMapError { $0.illegal ? fail($0.TemplateError!, on: eL)
                                                : self.searchSources(t, rest, on: eL) }
    }

}

private extension Error {
    var illegal: Bool {
        if case .illegalAccess = TemplateError?.reason { return true }
        return false
    }
}
