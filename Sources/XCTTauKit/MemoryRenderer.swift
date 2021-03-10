@testable import TauKit

/// Always uses in-memory file source and clears files/cache before tests.
///
/// Disallows changing the renderer setup and source
///
/// Defaults to `EmbeddedEventLoop` as the ELG. If using MTELG, test is responsible for tearing it down.
/// Defaults to `TemplateCache`, no special handling required for changes.
///
/// Adds `render(raw: String...` method for testing a String without using the source
open class MemoryRendererTestCase: TauKitTestCase {
    final public var files: MemorySource { super.source as! MemorySource }
    
    final public override var source: Source { get { super.source } set {} }
    final public override var renderer: Renderer { get { super.renderer } set {} }
    
    final public override func setUpTemplateEngine() throws {
        source = MemorySource()
        files.dropAll()
        cache.dropAll()
    }
    
    /// Convenience for rendering a raw string immediately - requires underlying ELG be embedded
    final public func render(raw: String,
                             _ context: Renderer.Context = .emptyContext(),
                             options: Renderer.Options = []) throws -> String {
        let key = "_raw_x\(files.keys.count)"
        files[key] = raw
        return try super.render(key, from: "$", context, options: options)
    }
}
