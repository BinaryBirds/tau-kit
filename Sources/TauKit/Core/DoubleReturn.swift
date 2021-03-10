internal extension Entities {
    func registerDoubleReturns() {
        use(DoubleIntToDoubleMap.rounded, asMethod: "rounded")
    }
}

/// (Array || Dictionary.values) -> Int
internal struct DoubleIntToDoubleMap: MapMethod, DoubleReturn {
    static var callSignature: [CallParameter] { [.double, .int(labeled: "places")] }

    func evaluate(_ params: CallValues) -> TemplateData { .double(f(params[0].double!, params[1].int!)) }

    static let rounded: Self = .init({let x = pow(10, Double($1)); return ($0*x).rounded(.toNearestOrAwayFromZero)/x})
    
    private init(_ map: @escaping (Double, Int) -> Double) { f = map }
    private let f: (Double, Int) -> Double
}

internal struct DoubleDoubleToDoubleMap: MapMethod, DoubleReturn {
    static var callSignature: [CallParameter] = [.double, .double]
    
    func evaluate(_ params: CallValues) -> TemplateData { .double(f(params[0].double!, params[1].double!)) }
    
    static let _min: Self = .init({ min($0, $1) })
    static let _max: Self = .init({ max($0, $1) })
    
    private init(_ map: @escaping (Double, Double) -> Double) { f = map }
    private let f: (Double, Double) -> Double
}
