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
    
    open var renderer: TemplateRenderer { TemplateRenderer(cache: cache,
                                                   sources: .singleSource(source),
                                                   eventLoop: eLGroup.next()) }
    
    @discardableResult
    final public func render(_ template: String,
                             from source: String = "$",
                             _ context: TemplateRenderer.Context = .emptyContext(),
                             options: TemplateRenderer.Options = []) throws -> String {
        precondition(renderer.eventLoop is EmbeddedEventLoop,
                     "Non-future render call must be on EmbeddedEventLoop")
        return try renderBuffer(template, from: source, context, options: options)
                    .map { String(decoding: $0.readableBytesView, as: UTF8.self) }.wait()
    }
    
    @discardableResult
    open func renderBuffer(_ template: String,
                             from source: String = "$",
                             _ context: TemplateRenderer.Context = .emptyContext(),
                             options: TemplateRenderer.Options = []) -> EventLoopFuture<ByteBuffer> {
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
               context: TemplateRenderer.Context = [:],
               options: TemplateRenderer.Options = []) throws -> AST {
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
        
        TemplateRenderer.Option.timeout = 0.050
        TemplateRenderer.Option.parseWarningThrows = true
        TemplateRenderer.Option.missingVariableThrows = true
        TemplateRenderer.Option.grantUnsafeEntityAccess = false
        TemplateRenderer.Option.encoding = .utf8
        TemplateRenderer.Option.caching = .default
        TemplateRenderer.Option.embeddedASTRawLimit = 4096
        TemplateRenderer.Option.pollingFrequency = 10.0
        
        TemplateBuffer.boolFormatter = { $0.description }
        TemplateBuffer.intFormatter = { $0.description }
        TemplateBuffer.doubleFormatter = { $0.description }
        TemplateBuffer.nilFormatter = { _ in "" }
        TemplateBuffer.stringFormatter = { $0 }
        TemplateBuffer.dataFormatter = { String(data: $0, encoding: $1) }
        
        DoubleFormatterMap.defaultPlaces = 2
        IntFormatterMap.defaultPlaces = 2

        TimestampEntity.referenceBase = .referenceDate
        DateFormatterEntities.defaultFractionalSeconds = false
        DateFormatterEntities.defaultTZIdentifier = "UTC"
        DateFormatterEntities.defaultLocale = "en_US_POSIX"
        
        TemplateSources.rootDirectory = "/"
        TemplateSources.defaultExtension = "html"
    }
}
