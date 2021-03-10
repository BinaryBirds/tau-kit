/// `Keyword`s are identifiers which take precedence over syntax/variable names - may potentially have
/// representable state themselves as value when used with operators (eg, `true`, `false` when
/// used with logical operators, `nil` when used with equality operators, and so forth)
public enum Keyword: String, Hashable, CaseIterable, TemplatePrintable {
    // MARK: - Cases
    //               Eval -> Bool / Other
    //            -----------------------
    case `in`,    //
         `true`,  //   X       T
         `false`, //   X       F
         `self`,  //   X             X
         `nil`,   //   X       F     X
         `yes`,   //   X       T
         `no`,    //   X       F
         `_`,     //
         template,    //
         `var`,   //
         `let`    //

    // MARK: - TemplatePrintable
    public var description: String { rawValue }
    public var short: String { rawValue }

    // MARK: Internal Only
    /// Whether the keyword has an evaluable representation
    internal var isEvaluable: Bool { [.true, .false, .yes, .no, .`self`, .nil].contains(self) }
    /// Whether the keyword can represent a logical value
    internal var isBooleanValued: Bool { [.true, .false, .yes, .no, .nil].contains(self) }
    /// Evaluate to a logical state, if possible
    internal var bool: Bool? { isBooleanValued ? [.true, .yes].contains(self) : nil }
    /// Variable declaration (var, let)
    internal var isVariableDeclaration: Bool{ [.`var`, .`let`].contains(self) }
}
