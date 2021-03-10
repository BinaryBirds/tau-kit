/// Wrapper for what is essentially deferred evaluation of `LDR` values to `TemplateData` as an intermediate
/// structure to allow general assembly of a contextual database that can be used/reused by `Renderer`
/// in various render calls. Values are either `variable` and can be updated/refreshed to their `TemplateData`
/// value, or `literal` and are considered globally fixed; ie, once literal, they can/should not be converted
/// back to `variable` as resolved ASTs will have used the pre-existing literal value.
internal struct TemplateDataValue: TemplateDataRepresentable {
    static func variable(_ value: TemplateDataRepresentable) -> Self { .init(value) }
    static func literal(_ value: TemplateDataRepresentable) -> Self { .init(value, true) }
    
    init(_ value: TemplateDataRepresentable, _ literal: Bool = false) {
        container = literal ? .literal(value.TemplateData) : .variable(value, .none) }
    
    var isVariable: Bool { container.isVariable }
    var TemplateData: TemplateData { container.TemplateData }
        
    var cached: Bool {
        if case .variable(_, .none) = container { return false }
        if case .literal(let d) = container, d.isLazy { return false }
        return true
    }
    
    /// Coalesce to a literal
    mutating func flatten() {
        let flat: TemplateDataContainer
        switch container {
            case .variable(let v, let d): flat = d?.container ?? v.TemplateData.container
            case .literal(let d): flat = d.container
        }
        container = .literal(flat.evaluate)
    }
    
    /// Update stored `TemplateData` value for variable values
    mutating func refresh() {
        if case .variable(let t, _) = container { container = .variable(t, t.TemplateData) } }
        
    /// Uncache stored `TemplateData` value for variable values
    mutating func uncache() {
        if case .variable(let t, .some) = container { container = .variable(t, .none) } }
    
    // MARK: - Private Only
    
    private enum Container: TemplateDataRepresentable {
        case literal(TemplateData)
        case variable(TemplateDataRepresentable, Optional<TemplateData>)
        
        var isVariable: Bool { if case .variable = self { return true } else { return false } }
        var TemplateData: TemplateData {
            switch self {
                case .variable(_, .some(let v)), .literal(let v) : return v
                case .variable(_, .none) : return .error(internal: "Value was not refreshed")
            }
        }
    }
    
    private var container: Container
}
