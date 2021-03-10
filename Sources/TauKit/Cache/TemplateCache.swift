
/// The default implementation of `Cache`
public final class TemplateCache {
    /// Initializer
    public init() {
        self.locks = (.init(), .init())
        self.cache = [:]
        self.touches = [:]
    }
    
    // MARK: - Stored Properties - Private Only
    private let locks: (cache: ReadWriteLock, touch: ReadWriteLock)
    /// NOTE: internal read-only purely for test access validation - not assured
    private(set) var cache: [AST.Key: AST]
    private var touches: [AST.Key: AST.Touch]
}

// MARK: - Public - Cache
extension TemplateCache: Cache {
    public var count: Int { locks.cache.readWithLock { cache.count } }
    
    public var isEmpty: Bool { locks.cache.readWithLock { cache.isEmpty } }
    
    public var keys: Set<AST.Key> { .init(locks.cache.readWithLock { cache.keys }) }

    /// - Parameters:
    ///   - document: The `AST` to store
    ///   - loop: `EventLoop` to return futures on
    ///   - replace: If a document with the same name is already cached, whether to replace or not.
    /// - Returns: The document provided as an identity return
    ///
    /// Use `AST.key` as the
    public func insert(_ document: AST,
                       on loop: EventLoop,
                       replace: Bool = false) -> EventLoopFuture<AST> {
        switch insert(document, replace: replace) {
            case .success(let ast): return succeed(ast, on: loop)
            case .failure(let err): return fail(err, on: loop)
        }
    }

    /// - Parameters:
    ///   - key: Name of the `AST`  to try to return
    ///   - loop: `EventLoop` to return futures on
    /// - Returns: `EventLoopFuture<AST?>` holding the `AST` or nil if no matching result
    public func retrieve(_ key: AST.Key,
                         on loop: EventLoop) -> EventLoopFuture<AST?> {
        succeed(retrieve(key), on: loop)
    }

    /// - Parameters:
    ///   - key: Name of the `AST`  to try to purge from the cache
    ///   - loop: `EventLoop` to return futures on
    /// - Returns: `EventLoopFuture<Bool?>` - If no document exists, returns nil. If removed,
    ///     returns true. If cache can't remove because of dependencies (not yet possible), returns false.
    public func remove(_ key: AST.Key,
                       on loop: EventLoop) -> EventLoopFuture<Bool?> {
        return succeed(remove(key), on: loop) }

    public func touch(_ key: AST.Key,
                      with values: AST.Touch) {
        locks.touch.writeWithLock { touches[key]?.aggregate(values: values) }
    }
    
    public func info(for key: AST.Key,
                     on loop: EventLoop) -> EventLoopFuture<AST.Info?> {
        succeed(info(for: key), on: loop)
    }
    
    public func dropAll() {
        locks.cache.writeWithLock {
            locks.touch.writeWithLock {
                cache.removeAll()
                touches.removeAll()
            }
        }
    }
}

// MARK: - Internal - SynchronousCache
extension TemplateCache: SynchronousCache {
    /// Blocking file load behavior
    func insert(_ document: AST, replace: Bool) -> Result<AST, TemplateError> {
        /// Blind failure if caching is disabled
        var e: Bool = false
        locks.cache.writeWithLock {
            if replace || !cache.keys.contains(document.key) {
                cache[document.key] = document
                locks.touch.writeWithLock { touches[document.key] = .empty }
            } else { e = true }
        }
        guard !e else { return .failure(err(.keyExists(document.name))) }
        return .success(document)
    }

    /// Blocking file load behavior
    func retrieve(_ key: AST.Key) -> AST? {
        return locks.cache.readWithLock {
            guard cache.keys.contains(key) else { return nil }
            locks.touch.writeWithLock {
                if touches[key]!.count >= 128,
                   let touch = touches.updateValue(.empty, forKey: key),
                   touch != .empty {
                    cache[key]!.touch(values: touch) }
            }
            return cache[key]
        }
    }

    /// Blocking file load behavior
    func remove(_ key: AST.Key) -> Bool? {
        if locks.touch.writeWithLock({ touches.removeValue(forKey: key) == nil }) { return nil }
        locks.cache.writeWithLock { _ = cache.removeValue(forKey: key) }
        return true
    }
    
    func info(for key: AST.Key) -> AST.Info? {
        locks.cache.readWithLock {
            guard cache.keys.contains(key) else { return nil }
            locks.touch.writeWithLock {
                if let touch = touches.updateValue(.empty, forKey: key),
                   touch != .empty {
                    cache[key]!.touch(values: touch) }
            }
            return cache[key]!.info
        }
    }
}
