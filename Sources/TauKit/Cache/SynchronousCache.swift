/// A `Cache` that provides certain blocking methods for non-future access to the cache
///
/// Adherents *MUST* be thread-safe and *SHOULD NOT* be blocking simply to avoid futures -
/// only adhere to this protocol if using futures is needless overhead. Currently restricted to TauKit internally.
internal protocol SynchronousCache: Cache {
    /// - Parameters:
    ///   - document: The `AST` to store
    ///   - replace: If a document with the same name is already cached, whether to replace or not
    /// - Returns: The document provided as an identity return when success, or a failure error
    func insert(_ document: AST, replace: Bool) -> Result<AST, TemplateError>

    /// - Parameter key: Name of the `AST` to try to return
    /// - Returns: The requested `AST` or nil if not found
    func retrieve(_ key: AST.Key) -> AST?

    /// - Parameter key: Name of the `AST`  to try to purge from the cache
    /// - Returns: `Bool?` If removed,  returns true. If cache can't remove because of dependencies
    ///      (not yet possible), returns false. Nil if no such cached key exists.
    func remove(_ key: AST.Key) -> Bool?
    
    func info(for key: AST.Key) -> AST.Info?
}
