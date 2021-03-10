/// `Cache` provides blind storage for compiled `AST` objects.
///
/// The stored `AST`s may or may not be fully renderable templates, and generally speaking no
/// attempts should be made inside a `Cache` adherent to make any changes to the stored document.
///
/// All definied access methods to a `Cache` adherent must guarantee `EventLoopFuture`-based
/// return values. For performance, an adherent may optionally provide additional, corresponding interfaces
/// where returns are direct values and not future-based by adhering to `SynchronousCache` and
/// providing applicable option flags indicating which methods may be used. This should only used for
/// adherents where the cache store itself is not a bottleneck. *NOTE* `SynchronousCache` is
/// currently internal-only to TauKit.
///
/// `AST.key: AST.Key` is to be used in all cases as the key for storing and retrieving cached documents.
public protocol Cache {
    /// Current count of cached documents
    var count: Int { get }
    /// If cache is empty
    var isEmpty: Bool { get }
    /// Keys for all currently cached ASTs
    var keys: Set<AST.Key> { get }

    /// - Parameters:
    ///   - document: The `AST` to store
    ///   - loop: `EventLoop` to return futures on
    ///   - replace: If a document with the same name is already cached, whether to replace or not.
    /// - Returns: The document provided as an identity return (or a failed future if it can't be inserted)
    func insert(_ document: AST,
                on loop: EventLoop,
                replace: Bool) -> EventLoopFuture<AST>

    /// - Parameters:
    ///   - key: `AST.key`  to try to return
    ///   - loop: `EventLoop` to return futures on
    /// - Returns: `EventLoopFuture<AST?>` holding the `AST` or nil if no matching result
    func retrieve(_ key: AST.Key,
                  on loop: EventLoop) -> EventLoopFuture<AST?>

    /// - Parameters:
    ///   - key: `AST.key`  to try to purge from the cache
    ///   - loop: `EventLoop` to return futures on
    /// - Returns: `EventLoopFuture<Bool?>` - If no document exists, returns nil. If removed,
    ///     returns true. If cache can't remove because of dependencies (not yet possible), returns false.
    func remove(_ key: AST.Key,
                on loop: EventLoop) -> EventLoopFuture<Bool?>
    
    /// Retrieve info for AST requested, if it's cached
    func info(for key: AST.Key,
              on loop: EventLoop) -> EventLoopFuture<AST.Info?>
    
    /// Touch the stored AST for `key` with the provided `AST.Touch` object via
    /// `AST.touch(values: AST.Touch)`, if document exists
    ///
    /// - Parameters:
    ///   - key: `AST.key` of the stored AST to touch
    ///   - value: `AST.Touch` to provide to the AST via `AST.touch(value)`
    ///
    /// If document doesn't exist, can be ignored; adherent may queue touches and aggregate them via
    /// `a.aggregate(b)`, and only touch when document or info is requested. As such, no event loop
    /// is provided - method should still not block.
    func touch(_ key: AST.Key,
               with value: AST.Touch)
    
    /// Drop the cache contents
    func dropAll()
}

public extension Cache {
    var isEmpty: Bool { count == 0 }
}
