/// Place all tests related to verifying that errors ARE thrown here
@testable import XCTTauKit

final class ErrorTests: MemoryRendererTestCase {
    /// Verify that cyclical references via #extend will throw `TemplateError.cyclicalReference`
    func testCyclicalError() {
        files["/a.html"] = "#inline(\"b\")"
        files["/b.html"] = "#inline(\"c\")"
        files["/c.html"] = "#inline(\"a\")"
        
        try XCAssertTemplateErrors(render("a"),
                             contains: "`a` cyclically referenced in [a -> b -> c -> !a]")
    }

    /// Verify that referecing a non-existent template will throw `TemplateError.noTemplateExists`
    func testDependencyError() {
        files["/a.html"] = "#inline(\"b\")"
        files["/b.html"] = "#inline(\"c\")"
        
        try XCAssertTemplateErrors(render("a"), contains: "No template found for `c`")
    }
}
