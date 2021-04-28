@testable import TauKit
import Dispatch

open class TauKitTestCase: XCTestCase {
    /// Override for per-test setup
    open func setUpTemplateEngine() throws {}
        
    open override class func setUp() {
        super.setUp()

        Self.queue.sync { _resetEngine() }
    }
    
    open override func setUpWithError() throws {
        try super.setUpWithError()

        try Self.queue.sync {
            addTeardownBlock {
                Self._resetEngine()
                if let files = self.source as? MemorySource { files.dropAll() }
                self.cache.dropAll()
            }
            try setUpTemplateEngine()
        }
    }
        
    open var eLGroup: EventLoopGroup = EmbeddedEventLoop()
    
    open var source: Source = MemorySource()
    open var cache: Cache = TemplateCache()
    
    open var renderer: Renderer { Renderer(cache: cache,
                                                   sources: .singleSource(source),
                                                   eventLoop: eLGroup.next()) }
    
    @discardableResult
    final public func render(_ template: String,
                             from source: String = "$",
                             _ context: Renderer.Context = .emptyContext(),
                             options: Renderer.Options = []) throws -> String {
        precondition(renderer.eventLoop is EmbeddedEventLoop,
                     "Non-future render call must be on EmbeddedEventLoop")
        return try renderBuffer(template, from: source, context, options: options)
                    .map { String(decoding: $0.readableBytesView, as: UTF8.self) }.wait()
    }
    
    @discardableResult
    open func renderBuffer(_ template: String,
                             from source: String = "$",
                             _ context: Renderer.Context = .emptyContext(),
                             options: Renderer.Options = []) -> EventLoopFuture<ByteBuffer> {
        renderer.render(template: template, from: source, context: context, options: options)
    }
    
    private static var queue = DispatchQueue(label: "TauKitTests")
}

internal extension TauKitTestCase {
    func startTauKit() {
        _primeEngine()
        if !TemplateConfiguration.started { TemplateConfiguration.started = true }
    }
    
    @discardableResult
    func lex(raw: String, name: String = "rawTemplate") throws -> [Token] {
        startTauKit()
        var lexer = Lexer(RawTemplate(name, raw))
        return try lexer.lex()
    }
    
    @discardableResult
    func parse(raw: String, name: String = "rawTemplate",
               context: Renderer.Context = [:],
               options: Renderer.Options = []) throws -> AST {
        let tokens = try lex(raw: raw, name: name)
        var context = context
        if context.options == nil { context.options = options }
        else { options._storage.forEach { context.options!.update($0) } }
        var parser = Parser(.searchKey(name), tokens, context)
        return try parser.parse()
    }
}

private extension TauKitTestCase {
    func _primeEngine() { if !TemplateConfiguration.isRunning { TemplateConfiguration.entities = .coreEntities } }
    
    static func _resetEngine() {
        #if DEBUG && canImport(XCTest)
        TemplateConfiguration.started = false
        #else
        fatalError("DO NOT USE IN NON-DEBUG BUILDS")
        #endif
        
        TemplateConfiguration.tagIndicator = .octothorpe
        TemplateConfiguration.entities = .coreEntities
        
        Renderer.Option.timeout = 0.050
        Renderer.Option.parseWarningThrows = true
        Renderer.Option.missingVariableThrows = true
        Renderer.Option.grantUnsafeEntityAccess = false
        Renderer.Option.encoding = .utf8
        Renderer.Option.caching = .default
        Renderer.Option.embeddedASTRawLimit = 4096
        Renderer.Option.pollingFrequency = 10.0
        
        TemplateBuffer.boolFormatter = { $0.description }
        TemplateBuffer.intFormatter = { $0.description }
        TemplateBuffer.doubleFormatter = { $0.description }
        TemplateBuffer.nilFormatter = { _ in "" }
        TemplateBuffer.stringFormatter = { $0 }
        TemplateBuffer.dataFormatter = { String(data: $0, encoding: $1) }
        
        DoubleFormatterMap.defaultPlaces = 2
        IntFormatterMap.defaultPlaces = 2

        Timestamp.referenceBase = .referenceDate
        DateFormatters.defaultFractionalSeconds = false
        DateFormatters.defaultTZIdentifier = "UTC"
        DateFormatters.defaultLocale = "en_US_POSIX"
        
        TemplateSources.rootDirectory = "/"
        TemplateSources.defaultExtension = "html"
    }
}
