/// A `VariableTable` provides a Dictionary of concrete `TemplateData` available for a symbolic key
internal typealias VariableTable = [Variable: TemplateData]
/// UnsafeMutablePointer to `[Variable: TemplateData]`
internal typealias VariableTablePointer = UnsafeMutablePointer<VariableTable>

internal extension VariableTablePointer {
    func match(_ key: Variable) -> TemplateData? { pointee.match(key) }
    func dropDescendents(of key: Variable) { pointee.dropDescendents(of: key) }
}

internal extension VariableTable {
    /// Locate the `Variable` in the table, if possible. Never use with scoped variable.
    ///
    /// If variable is pathed and the root object exists, auto-expands the variable path into the table to retain
    /// for future accession.
    mutating func match(_ key: Variable) -> TemplateData? {
        func err(_ root: Variable, _ child: Variable) -> TemplateData {
            .error(internal: "\(root.terse) is not a dictionary; \(child.terse) is invalid") }
        
        if let hit = self[key] { return hit }
        
        /// If table holds variable or variable is atomic, immediately return result or nil
        guard !keys.contains(key), key.isPathed else { return self[key] }
        
        var root = key.ancestor
        guard let hit = self[root] else { return nil }
        guard hit.storedType == .dictionary else { return err(root, key) }
        root = key.parent!
        var path = [key.lastPart!]
        /// Move root up until hitting an actual value (possibly ancestor)
        while self[root] == nil { path.append(root.lastPart!); root = root.parent! }
        while let dict = self[root]!.dictionary {
            let part = path.removeLast()
            root = root.extend(with: part)
            guard let hit = dict[part] else { if !path.isEmpty { break } else { return nil } }
            self[root] = hit
            if path.isEmpty { return hit }
        }
        self[key] = err(root, key)
        return self[key]
    }
    
    mutating func dropDescendents(of key: Variable) {
        keys.forEach { if $0.isDescendent(of: key) { self[$0] = nil } }
    }
}
