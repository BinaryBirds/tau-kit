/// An object that can be registered to a `Renderer.Context` and automatically have its published
/// variables inserted to the scope specified by an API user.
///
/// Example usage: in the below, a struct for tracking API versioning contains the API identifier and semver
/// values. By registering the object with the `Renderer.Context` object, a custom tag will have
/// access to `externalObjects["api"]` (the actual `APIVersioning` object) during its evaluation
/// call, if unsafe access is enabled, and the `.ObjectMode` contains `.unsafe`
///
/// Additionally, because the object adheres to `ContextPublisher`, the values returned by
/// `variables()` will be registered as variables available *in the serialized template*... eg,
/// `#($api.version.major)` will serialize as `0`, if `.ObjectMode` contains `.contextualized`
///
/// If the context object is further directed to lock `api` scope as a global literal value, `$api` and its
/// values *will be automatically flattened* and available during parsing of a template; inlining their values
/// and thus optimize performance during serializing
/// ```
/// // A core object adhering to `ContextPublisher`
/// class APIVersioning: ContextPublisher {
///     init(_ a: String, _ b: (Int, Int, Int)) { self.identifier = a; self.version = b }
///
///     let identifier: String
///     let version: (major: Int, minor: Int, patch: Int)
///
///     lazy var variables: [String: TemplateDataGenerator] = [
///         "identifier" : .immediate(identifier),
///         "version"    : .lazy(["major": self.version.major,
///                               "minor": self.version.minor,
///                               "patch": self.version.patch])
///     ]
/// }
///
/// // An example extension of the object allowing an additional set of
/// // user-configured additional generators
/// extension APIVersioning {
///     var extendedVariables: [String: TemplateDataGenerator] {[
///         "isRelease": { .lazy(version.major > 0) }
///     ]}
/// }
///
/// let myAPI = APIVersioning("api", (0,0,1))
///
/// var aContext: Renderer.Context = [:]
/// try aContext.register(object: myAPI, toScope: "api")
/// try aContext.register(generators: myAPI.extendedVariables, toScope: "api")
/// // Result of `#($api.version)`:
/// // ["major": 0, "minor": 0, "patch": 1]
/// myAPI.version.major = 1
/// // Result of `#($api.version)` in subequent render:
/// // ["major": 1, "minor": 0, "patch": 1]
/// ```
public protocol ContextPublisher {
    /// First-level API provider that adheres an object *it owns* to this protocol must implement `variables`
    var templateVariables: [String: TemplateDataGenerator] { get }
}
