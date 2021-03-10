/// Provide `description` and `short` printable representations for convenience
internal protocol TemplatePrintable: CustomStringConvertible {
    /// - Ex: `bool(true)` or `raw("This is a raw block")` - description should be descriptive
    var description: String { get }

    /// - Ex: `true` or `raw(19)` - short form should be descriptive but succinct
    var short: String { get }
}

/// Adhere to `Symbol`to provide generic property/method that allow resolution by TauKit
internal protocol Symbol: TemplatePrintable {
    /// If the symbol is fully resolved
    ///
    /// An unresolved symbol is equivalent to nil at the time of inquiry, but *may* be resolvable.
    var resolved: Bool { get }

    /// If the symbol can be safely evaluated at arbitrary times
    ///
    /// A *variant* symbol is something that may produce different results *for the same input* (eg Date())
    var invariant: Bool { get }

    /// Any variables this symbol requires to fully resolve.
    var symbols: Set<Variable> { get }

    /// Attempt to resolve with provided symbols.
    ///
    /// Always returns the same type of object,
    func resolve(_ symbols: inout VariableStack) -> Self

    /// Force attempt to evalute the symbol with provided symbols
    ///
    /// Atomic symbols should always result in `TemplateData` or`.trueNil` if unevaluable due to lack
    /// of needed symbols, or if a non-atomic (eg, `Tuple` or a non-calculation `Expression`)
    func evaluate(_ symbols: inout VariableStack) -> TemplateData
}

