/// `TemplateDataGenerator` is a wrapper for passing `TemplateDataRepresentable` objects to
/// `Renderer.Context` while deferring conversion to `TemplateData` until being accessed
///
/// In all cases, conversion of the `TemplateDataRepresentable`-adhering parameter to concrete
/// `TemplateData` is deferred until it is actually accessed by `Renderer` (when a template has
/// accessed its value).
///
/// Can be created as either immediate storage of the parameter, or lazy generation of the
/// `TemplateDataRepresentable` object itself in order to provide an additional lazy level in the case of items
/// that may have costly conversion procedures (eg, `Encodable` auto-conformance), or to allow a
/// a generally-shared global `.Context` object to be used repeatedly.
public struct TemplateDataGenerator {
    /// Produce a generator that immediate stores the parameter
    public static func immediate(_ value: TemplateDataRepresentable) -> Self {
        .init(.immediate(value)) }
    
    /// Produce a generator that defers evaluation of the parameter until `Renderer` accesses it
    public static func lazy(_ value: @escaping @autoclosure () -> TemplateDataRepresentable) -> Self {
        .init(.lazy(.lazy(f: {value().templateData}, returns: .void))) }
    
    init(_ value: Container) { self.container = value }
    let container: Container
    
    enum Container: TemplateDataRepresentable {
        case immediate(TemplateDataRepresentable)
        case lazy(TemplateDataContainer)
        
        var templateData: TemplateData {
            switch self {
                case .immediate(let ldr): return ldr.templateData
                case .lazy(let lkd): return .init(lkd.evaluate)
            }
        }
    }
}
