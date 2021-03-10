internal extension Entities {
    func registerStringReturns() {
        use(StrToStrMap.uppercased,  asMethod: "uppercased")
        use(StrToStrMap.lowercased,  asMethod: "lowercased")
        use(StrToStrMap.capitalized, asMethod: "capitalized")
    }
}

/// (String) -> String
internal struct StrToStrMap: MapMethod, StringParam, StringReturn {
    func evaluate(_ params: CallValues) -> TemplateData { .string(f(params[0].string!)) }
    
    static let uppercased: Self = .init({ $0.uppercased() })
    static let lowercased: Self = .init({ $0.lowercased() })
    static let capitalized: Self = .init({ $0.capitalized })
    static let reversed: Self = .init({ String($0.reversed()) })
    static let randomElement: Self = .init({ $0.isEmpty ? nil : String($0.randomElement()!) })
    static let escapeHTML: Self = .init({ $0.reduce(into: "", {$0.append(basicHTML[$1] ?? $1.description)}) })
    
    private init(_ map: @escaping (String) -> String?) { f = map }
    private let f: (String) -> String?
    
    private static let basicHTML: [Character: String] = [
        .lessThan: "&lt;", .greaterThan: "&gt;", .ampersand: "&amp;", .quote: "&quot;", .apostrophe: "&apos;"
    ]
}

internal struct StrStrStrToStrMap: MapMethod, StringReturn {
    static var callSignature:[CallParameter] {[
        .string, .string(labeled: "occurencesOf"), .string(labeled: "with")
    ]}
    
    func evaluate(_ params: CallValues) -> TemplateData {
        .string(f(params[0].string!, params[1].string!, params[2].string!)) }
    
    static let replace: Self = .init({ $0.replacingOccurrences(of: $1, with: $2) })
    
    private init(_ map: @escaping (String, String, String) -> String) { f = map }
    private let f: (String, String, String) -> String
}
