internal extension Entities {

    func registerErroring() {
        use(IdentityErrorEntity(), asFunction: "Error")
        use(ThrowingErrorEntity(), asFunction: "throw")
    }
}

internal protocol ErrorEntity: Invariant, VoidReturn {}

extension ErrorEntity {

    func evaluate(_ params: CallValues) -> TemplateData {
        .error(params[0].string!, function: String(describing: self))
    }
}

internal struct IdentityErrorEntity: ErrorEntity {

    static var callSignature: [CallParameter] {
        [.init(types: .string, defaultValue: .string("Unknown serialize error"))]
    }
}

internal struct ThrowingErrorEntity: ErrorEntity {

    static var callSignature: [CallParameter] {
        [.string(labeled: "reason", defaultValue: .string("Unknown serialize error"))]
    }
}
