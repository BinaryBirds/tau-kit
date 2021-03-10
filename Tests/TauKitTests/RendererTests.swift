@testable import XCTTauKit
@testable import TauKit

final class RendererTests: MemoryRendererTestCase {

    func testNestedEcho() throws {
        try XCTAssertEqual(render(raw: "Todo: #(todo.title)",
                                  ["todo": ["title": "Template!"]]),
                           "Todo: Template!")
    }

    func testRendererContext() throws {
        struct CustomTag: UnsafeEntity, StringReturn {
            static var callSignature: [CallParameter]  {[.string]}
            
            var unsafeObjects: UnsafeObjects? = nil
            var prefix: String? { unsafeObjects?["prefix"] as? String }
            
            func evaluate(_ params: CallValues) -> TemplateData {
                .string((prefix ?? "") + params[0].string!) }
        }
        
        TemplateConfiguration.entities.use(CustomTag(), asFunction: "custom")
        
        files["foo"] = "Hello #custom(name)"
        
        var baseContext: Renderer.Context = ["name": "vapor"]
        var moreContext: Renderer.Context = [:]
        try moreContext.register(object: "bar", toScope: "prefix", type: .unsafe)
        try baseContext.overlay(moreContext)
        
        try XCTAssertEqual(render("foo", baseContext), "Hello barvapor")
    }

    func testImportResolve() {
        Renderer.Option.parseWarningThrows = false
        
        files["a"] = """
        #define(value = "Hello")
        #inline("b")
        """
        files["b"] = "#evaluate(value)"

        try XCTAssertEqual(render("a"), "Hello")
    }

    func testImportParameter() throws {
        files["base"] = """
        #define(adminValue = admin)
        #inline("parameter")
        """
        files["delegate"] = """
        #define(delegated = false || bypass)
        #inline("parameter")
        """
        files["parameter"] = """
        #if(evaluate(adminValue ?? false)):
            Hi Admin
        #elseif(evaluate(delegated ?? false)):
            Also an admin
        #else:
            No Access
        #endif
        """
        
        try XCTAssertEqual(render("base", ["admin": false]).trimmed, "No Access")
        try XCTAssertEqual(render("base", ["admin": true]).trimmed, "Hi Admin")
        try XCTAssertEqual(render("delegate", ["bypass": true]).trimmed, "Also an admin")
    }

    func testDeepResolve() throws {
        files["a"] = """
        #for(a in b):
        #if(false):
        Hi
        #elseif(true && false):
        Hi
        #else:
        #define(derp):
        DEEP RESOLUTION #(a)
        #enddefine
        #inline("b")
        #endif
        #endfor
        """
        files["b"] = "#evaluate(derp)\n"

        let expected = """
        DEEP RESOLUTION 1
        DEEP RESOLUTION 2
        DEEP RESOLUTION 3

        """

        try XCTAssertEqual(render("a", .init(["b":["1","2","3"]])), expected)
    }
    
    func testInline() throws {
        Renderer.Option.missingVariableThrows = false
        
        files["template"] = """
        #(var variable = 10)
        #inline("external", as: raw)
        #inline("external", as: template)
        #inline("external")
        """
        files["external"] = "#(variable)\n"
        files["uncachedraw"] = #"#inline("excessiveraw.txt", as: raw)"#
        files["excessiveraw.txt"]  = .init(repeating: ".",
                                           count: Int(Renderer.Option.embeddedASTRawLimit) + 1)
        
        let expected = """
        #(variable)
        10
        10

        """
        
        try XCTAssertEqual(render("template"), expected)
        try XCTAssertTrue(renderer.info(for: "template").wait()!.resolved)
        
        try XCTAssertTrue(render("uncachedraw").count == Int(Renderer.Option.embeddedASTRawLimit) + 1)
        
        let ast = (renderer.cache as! TemplateCache).retrieve(.searchKey("uncachedraw"))!
        XCTAssertTrue(ast.info.requiredRaws.contains("excessiveraw.txt"))
    }
    
    func testType() throws {
        let template = """
        #type(of: 0)
        #type(of: 0.0)
        #type(of: "0")
        #type(of: [0])
        #type(of: ["zero": 0])
        #(x.type())
        #if(x.type() == "String?"):x is an optional String#endif
        """
        
        let expected = """
        Int
        Double
        String
        Array
        Dictionary
        String?
        x is an optional String
        """
        
        try XCTAssertEqual(render(raw: template, ["x": .string(nil)]), expected)
    }
    
    func testRawBlock() throws {
        let template = """
        #raw():
        Body
            #raw():
            More Body #("and a" + variable)
            #endraw
        #endraw
        """
        
        let expected = """
        0: raw:
        1: scope(table: 1)
           0: raw(TemplateBuffer: 10B)
           1: raw:
           2: scope(table: 2)
              0: raw(TemplateBuffer: 15B)
              1: [string(and a) + $:variable]
              2: raw(TemplateBuffer: 5B)
        """
        
        try XCAssertTemplateErrors(parse(raw: template).terse == expected,
                             contains: "1:1 - Raw switching blocks not yet supported")
    }
    
    func testContexts() throws {
        let myAPI = _APIVersioning("myAPI", (0,0,1))
        
        var aContext: Renderer.Context = [:]
        
        try aContext.register(object: myAPI, toScope: "api")
        try aContext.register(generators: myAPI.extendedVariables, toScope: "api")
                
        files["template"] = """
        #if(!$api.isRelease && !override):#Error("This API is not vended publically")#endif
        #($api ? $api : throw(reason: "No API information"))
        Results!
        """
        let expected = """
        ["identifier": "myAPI", "isRelease": false, "version": ["major": 0, "minor": 0, "patch": 1]]
        Results!
        """
                
        try XCAssertTemplateErrors(render("template", aContext), contains: "[self.override] variable(s) missing")
        aContext["override"] = true
        try XCTAssertEqual(render("template", aContext), expected)
        myAPI.version.major = 1
        try XCTAssert(render("template", aContext).contains("\"major\": 1"))
    }
    
    func testEncoderEncodable() throws {
        struct Test: Encodable, Equatable {
            let fieldOne: String = "One"
            let fieldTwo: Int = 2
            let fieldThree: Double = 3.0
            let fieldFour = ["One", "Two", "Three", "Four"]
            let fieldFive = ["a": "A", "b": "B", "c": "C"]
            
            static func ==(lhs: Test, rhs: Test) -> Bool { true }
        }
        
        let encoder = TemplateDataEncoder()
        let encodable = Test()
        try encodable.encode(to: encoder)
        
        files["template"] = """
        #(test.fieldOne)
        #(test.fieldTwo)
        #(test.fieldThree)
        #(test.fieldFour)
        #(test.fieldFive)
        """
        
        let expected = """
        One
        2
        3.0
        ["One", "Two", "Three", "Four"]
        ["a": "A", "b": "B", "c": "C"]
        """
            
        try XCTAssertEqual(expected, render("template",
                                            .init(["test": encoder.templateData])))
        try XCTAssertEqual(expected, render("template",
                                  Renderer.Context(encodable: ["test": encodable])!))
    }
    
    func testElideRenderOptionChanges() throws {
        var options = Renderer.Options.globalSettings
        
        XCTAssertEqual(Renderer.Option.Case.allCases.count,
                       Renderer.Option.allCases.count)
        XCTAssertEqual(Renderer.Option.allCases.count, 8)
        XCTAssertEqual(options._storage.count, 0)
        options.update(.timeout(1.0))
        XCTAssertEqual(options._storage.count, 1)
        options.unset(.timeout)
        XCTAssertEqual(options._storage.count, 0)
    }
    
    func testRenderOptions() throws {
        files["template"] = "Original Template"
                
        func render(bypass: Bool = false) throws -> String {
            try self.render("template", options: [.caching(bypass ? .bypass : .default)]) }
        
        try XCTAssertEqual(render(), "Original Template")
        
        files["template"] = "Updated Template"
        
        try XCTAssertEqual(render(), "Original Template")
        try XCTAssertEqual(render(bypass: true), "Updated Template")
    }
    
    func testMisc() throws {
        TemplateConfiguration.entities.use(IntIntToIntMap._min, asFunction: "min")
        TemplateConfiguration.entities.use(IntIntToIntMap._max, asFunction: "max")
        try XCTAssertEqual(render(raw: "#min(1, 0)"), "0")
        try XCTAssertEqual(render(raw: "#max(1, 0)"), "1")
    }
    
    /// µ is 2byte with lower 0xB5 in UTF8, 1byte 0x9D in NeXT encoding
    func testEncoding() throws {
        files["micro"] = "µ"
        files["tau"] = "τ"
        let utf: Renderer.Options = [.encoding(.utf8)]
        let ns: Renderer.Options = [.encoding(.nextstep)]
                
        var buffer = try renderBuffer("micro", options: utf).wait()
        XCTAssertEqual(buffer.readBytes(length: 2)![1], 0xB5)
        
        buffer = try renderBuffer("micro", options: ns).wait()
        XCTAssertEqual(buffer.readBytes(length: 1)![0], 0x9D)
        
        buffer = try renderBuffer("tau", options: utf).wait()
        XCTAssertEqual(buffer.readBytes(length: 2)![1], 0x84)
        
        try XCAssertTemplateErrors(render("tau", options: ns),
                             contains: "`τ` is not encodable to `Western (NextStep)`")
    }
    
    func testContextInfo() throws {
        var aContext = Renderer.Context()
        
        let one = ["key1": 1, "key2": 2]
        let two = ["key3": false, "key4": true]
        let three = ["key5": 5.0]
        
        try aContext.register(object: one, toScope: "scopeOne")
        try aContext.register(object: two, toScope: "scopeOne")
        try aContext.register(object: three, toScope: "scopeTwo")
        
        let scopes: Set<String> = .init(aContext.registeredContextScopes)
        let objects: Set<String> = .init(aContext.registeredContextObjects
                                            .map {"\($0.0): \(String(describing: type(of:$0.1)))"})
        
        XCTAssertEqual(scopes, ["context", "scopeOne", "scopeTwo"])
        XCTAssertEqual(objects, ["scopeOne: Dictionary<String, Int>",
                                 "scopeOne: Dictionary<String, Bool>",
                                 "scopeTwo: Dictionary<String, Double>"])
    }
    
    func testAutoUpdate() throws {
        Renderer.Option.pollingFrequency = 0.000_001
        
        files["template"] = "Hi"
        try XCTAssertEqual(render("template"), "Hi")
        
        usleep(10)
        
        files["template"] = "Bye"
        try XCTAssertEqual(render("template"), "Bye")
    }
}
