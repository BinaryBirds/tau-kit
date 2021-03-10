public struct DoubleFormatterMap: MapMethod, StringReturn {
    @RuntimeGuard public static var defaultPlaces: UInt8 = 2
    
    public static var callSignature: [CallParameter] {[
        .double, .int(labeled: "places", defaultValue: Int(Self.defaultPlaces).templateData)
    ]}
        
    public func evaluate(_ params: CallValues) -> TemplateData {
        .string(f(params[0].double!, params[1].int!))  }
    
    static let seconds: Self = .init({$0.formatSeconds(places: Int($1))})
    
    private init(_ map: @escaping (Double, Int) -> String) { f = map }
    private let f: (Double, Int) -> String
}

public struct IntFormatterMap: MapMethod, StringReturn {
    @RuntimeGuard public static var defaultPlaces: UInt8 = 2
    
    public static var callSignature: [CallParameter] {[
        .int, .int(labeled: "places", defaultValue: Int(Self.defaultPlaces).templateData)
    ]}
        
    public func evaluate(_ params: CallValues) -> TemplateData {
        .string(f(params[0].int!, params[1].int!)) }
    
    internal static let bytes: Self = .init({$0.formatBytes(places: Int($1))})
    
    private init(_ map: @escaping (Int, Int) -> String) { f = map }
    private let f: (Int, Int) -> String
}
