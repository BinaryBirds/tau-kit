public extension Encodable {
    func encodeToTemplateData() -> TemplateData {
        let encoder = TemplateDataEncoder()
        do { try encode(to: encoder) }
        catch { return .error(internal: "Could not encode \(String(describing: self)) to `TemplateData`)") }
        return encoder.TemplateData
    }
}
