internal struct Tuple: Symbol {
    // MARK: - Stored Properties

    var values: [Parameter] { didSet { setStates() } }
    var labels: [String: Int] { didSet { setStates() } }
    var collection: Bool = false

    // MARK: Symbol
    private(set) var resolved: Bool
    private(set) var invariant: Bool
    private(set) var symbols: Set<Variable>
    

    // MARK: - Initializer
    init(_ tuple: [(label: String?, param: Parameter)] = []) {
        self.values = []
        self.labels = [:]
        self.symbols = []
        self.resolved = true
        self.invariant = true
        self.isEvaluable = true
        for index in 0..<tuple.count {
            values.append(tuple[index].param)
            if let label = tuple[index].label { labels[label] = index }
        }
    }

    // MARK: - Computed Properties
    // MARK: TemplatePrintable
    /// `(_: value(1), isValid: bool(true), ...)`
    var description: String {
        let x = collection ? "\"" : "" // If collection, wrap labels in quotes
        let inverted = Dictionary(uniqueKeysWithValues: labels.map { ($0.value, $0.key) })
        let labeled = values.enumerated().map { "\(x)\(inverted[$0] ?? "_ ")\(x): \($1.description)" }
        return wrap(labeled.joined(separator: ", "))
    }

    /// `(value(1), bool(true), ...)`
    var short: String { wrap(values.map {$0.short}.joined(separator: ", ")) }

    private func wrap(_ s: String) -> String { collection ? "[\(s)]" : "(\(s))" }
    
    // MARK: Symbol
    func resolve(_ symbols: inout VariableStack) -> Self {
        if resolved { return self }
        var updated = self
        for index in values.indices where !values[index].resolved {
            updated.values[index] = values[index].resolve(&symbols)
        }
        return updated
    }
    
    func evaluate(_ symbols: inout VariableStack) -> TemplateData {
        if labels.isEmpty {
            return .array(values.map { $0.evaluate(&symbols) })
        } else {
            let inverted = Dictionary(labels.map { ($0.value, $0.key) }, uniquingKeysWith: {a, _ in a})
            let dict = values.indices.map { (inverted[$0]!, values[$0].evaluate(&symbols)) }
            return .dictionary(.init(uniqueKeysWithValues: dict))
        }
    }
    
    private(set) var isEvaluable: Bool
    
    var baseType: TemplateDataType? { labels.count == values.count ? .dictionary : labels.count == 0 ? .array : nil }

    // MARK: Fake Collection Adherence
    var isEmpty: Bool { values.isEmpty }
    var count: Int { values.count }

    var enumerated: [(label: String?, value: Parameter)] {
        let inverted = Dictionary(uniqueKeysWithValues: labels.map { ($0.value, $0.key) })
        return values.enumerated().map { (inverted[$0.offset], $0.element) }
    }

    subscript(index: String) -> Parameter? {
        get { if let i = labels[index] { return i < count ? self[i] : nil }; return nil }
        set { if let i = labels[index], i < count { self[i] = newValue } }
    }

    subscript(index: Int) -> Parameter? {
        get { (0..<count).contains(index) ? values[index] : nil }
        set { if (0..<count).contains(index) { values[index] = newValue! } }
    }

    mutating func append(_ more: Self) {
        values.append(contentsOf: more.values)
        more.labels.mapValues { $0 + self.count }.forEach { labels[$0.key] = $0.value }
    }

    // MARK: Private Only

    mutating private func setStates() {
        resolved = values.allSatisfy { $0.resolved }
        invariant = values.allSatisfy { $0.invariant }
        symbols = values.reduce(into: .init()) { $0.formUnion($1.symbols) }
        
        isEvaluable = baseType != nil
        if values.first(where: {!$0.isValued}) != nil { isEvaluable = false }
    }
}
