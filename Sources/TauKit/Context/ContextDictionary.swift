/// Storage setup equivalent for `$aContext` and its various parts in a template file. Entire dictionary may be
/// set `literal` or discrete value entries inside a variable dictionary could be literal; eg `$context` is
/// a potentially variable context, but `$context.aLiteral` will be set literal (and in ASTs, resolved to its
/// actual value when parsing a template).
internal struct ContextDictionary {
    /// Scope parent
    let parent: Variable
    /// Only returns top level scope & atomic variables to defer evaluation of values
    private(set) var values: [String: TemplateDataValue] = [:]
    private(set) var allVariables: Set<Variable>
    private(set) var literal: Bool = false
    private(set) var frozen: Bool = false
    private var cached: VariableTable = [:]
    
    init(_ parent: Variable, _ literal: Bool = false) {
        self.parent = parent
        self.literal = literal
        self.allVariables = [parent]
    }
    
    /// Only settable while not frozen
    subscript(key: String) -> TemplateDataValue? {
        get { values[key] }
        set {
            guard !frozen else { return }
            defer { cached[parent] = nil }
            guard let newValue = newValue else {
                values[key] = nil; allVariables.remove(parent.extend(with: key)); return }
            guard values[key] == nil else {
                values[key] = newValue; return }
            if key.isValidIdentifier { allVariables.insert(parent.extend(with: key)) }
            values[key] = newValue
        }
    }
        
    /// Set all values, overwriting any that already exist
    mutating func setValues(_ values: [String: TemplateDataRepresentable],
                            allLiteral: Bool = false) {
        literal = allLiteral
        values.forEach {
            if $0.isValidIdentifier { allVariables.insert(parent.extend(with: $0)) }
            self[$0] = allLiteral ? .literal($1) : .variable($1)
        }
    }
    
    /// With empty string, set entire object & all values to literal; with key string, set value to literal
    mutating func setLiteral(_ key: String? = nil) {
        if let key = key { return self[key]?.flatten() ?? () }
        for (key, val) in values where !val.cached { self[key]!.flatten() }
        literal = true
    }

    /// Obtain `[Variable: TemplateData]` for variable; freezes state of context as soon as accessed
    ///
    /// If a specific variable, flatten result if necessary and return that element
    /// If the parent variable, return a dictionary data elelement for the entire scope, and cached copies of
    /// individually referenced objects
    mutating func match(_ key: Variable) -> Optional<TemplateData> {
        if let hit = cached[key] { return hit }
        
        if key.isPathed {
            let root = key.ancestor
            if !allVariables.contains(root) || match(root) == nil { return .none }
            return cached.match(key)
        }
        else if !allVariables.contains(key) { return .none }
        
        frozen = true
        
        let value: Optional<TemplateData>
        if key == parent {
            for (key, value) in values where !value.cached { values[key]!.flatten() }
            value = .dictionary(values.mapValues {$0.templateData})
        } else {
            let member = key.member!
            if !values[member]!.cached { values[member]!.flatten() }
            value = values[member]!.templateData
        }
        cached[key] = value
        return value
    }
}
