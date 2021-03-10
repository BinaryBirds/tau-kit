import Foundation
import NIOConcurrencyHelpers

internal extension Entities {

    func registerTimestampAndDate() {
        use(Timestamp(), asFunction: "Timestamp")
        use(DateFormatters.ISO8601(), asFunction: "Date")
        use(DateFormatters.Fixed(), asFunction: "Date")
        use(DateFormatters.Localized(), asFunction: "Date")
    }
}

// MARK: - Timestamp

/// A time interval relative to the specificed base date
///
/// Default value for the reference date is the Swift Date `referenceDate` (2001-01-01 00:00:00 +0000)
public struct Timestamp: Function, DoubleReturn {
    /// The date used as the reference base for all interpretations of Double timestamps
    @RuntimeGuard public static var referenceBase: ReferenceBase = .referenceDate
    
    public static var callSignature: [CallParameter] {[
        .init(types: [.int, .double, .string], defaultValue: "now"),
        .string(labeled: "since", defaultValue: referenceBase.templateData),
    ]}
    
    public func evaluate(_ params: CallValues) -> TemplateData {
        guard let base = ReferenceBase(rawValue: params[1].string!) else {
            return .error("\(params[1].string!) is not a valid reference base; must be one of \(ReferenceBase.allCases.description)") }
        let offset = base.interval
        if Set<TemplateDataType>.numerics.contains(params[0].storedType) {
            return .double(Date(timeIntervalSinceReferenceDate: offset + params[0].double!)
                            .timeIntervalSinceReferenceDate) }
        guard let x = ReferenceBase(rawValue: params[0].string!) else { return ReferenceBase.fault(params[0].string!) }
        return .double(base == x ? 0 : x.interval - offset)
    }
    
    public static var invariant: Bool { false }
    
    public enum ReferenceBase: String, RawRepresentable, CaseIterable, TemplateDataRepresentable {
        case now
        case unixEpoch
        case referenceDate
        case distantPast
        case distantFuture
        
        public var templateData: TemplateData { .string(rawValue) }
    }
}

public struct DateFormatters {
    /// Used by `ISO8601`, `Fixed`, & `.Custom`
    @RuntimeGuard(condition: {TimeZone(identifier: $0) != nil})
    public static var defaultTZIdentifier: String = "UTC"
    
    /// Used by `ISO8601`
    @RuntimeGuard
    public static var defaultFractionalSeconds: Bool = false
    
    /// Used by `Custom`
    @RuntimeGuard(condition: {Locale.availableIdentifiers.contains($0)})
    public static var defaultLocale: String = "en_US_POSIX"
    
    /// ISO8601 Date strings
    public struct ISO8601: Function, StringReturn, Invariant {
        public static var callSignature: [CallParameter] {[
            .init(types: [.int, .double, .string], defaultValue: .lazy(now, returns: .double)),
            .string(labeled: "timeZone", defaultValue: defaultTZIdentifier.templateData),
            .bool(labeled: "fractionalSeconds", defaultValue: defaultFractionalSeconds.templateData)
        ]}
        
        public func evaluate(_ params: CallValues) -> TemplateData {
            let timestamp = params[0]
            let zone = params[1].string!
            let fractional = params[2].bool!
            var interval: Double
            
            if timestamp.isNumeric { interval = timestamp.double! }
            else {
                guard let t = Timestamp.ReferenceBase(rawValue: timestamp.string!) else {
                    return Timestamp.ReferenceBase.fault(timestamp.string!) }
                interval = t.interval
            }
            
            var formatter = DateFormatters[zone, fractional]
            if formatter == nil {
                guard let tZ = TimeZone(identifier: zone) else {
                    return .error("\(zone) is not a valid time zone identifier") }
                formatter = ISO8601DateFormatter()
                formatter!.timeZone = tZ
                if fractional { formatter!.formatOptions.update(with: .withFractionalSeconds) }
                DateFormatters[zone, fractional] = formatter
            }
            return .string(formatter!.string(from: base.addingTimeInterval(interval)))
        }
    }
    
    /// Fixed format DateFormatter strings
    public struct Fixed: Function, StringReturn, Invariant {
        public static var callSignature: [CallParameter] {[
            .init(label: "timeStamp", types: [.int, .double, .string]),
            .string(labeled: "fixedFormat"),
            .string(labeled: "timeZone", defaultValue: defaultTZIdentifier.templateData),
        ]}
        
        public func evaluate(_ params: CallValues) -> TemplateData {
            DateFormatters.evaluate(params, fixed: true) }
    }
    
    /// Variable format localized DateFormatter strings
    public struct Localized: Function, StringReturn, Invariant {
        public static var callSignature: [CallParameter] {[
            .init(label: "timeStamp", types: [.int, .double, .string]),
            .string(labeled: "localizedFormat"),
            .string(labeled: "timeZone", defaultValue: defaultTZIdentifier.templateData),
            .string(labeled: "locale", defaultValue: defaultLocale.templateData)
        ]}
        
        public func evaluate(_ params: CallValues) -> TemplateData {
            DateFormatters.evaluate(params, fixed: false) }
    }
    
    // MARK: Internal Only
    
    internal struct Key: Hashable {
        let format: String
        let tZ: String
        let locale: String?
        
        init(_ format: String, _ tZ: String, _ locale: String? = nil) {
            self.format = format
            self.tZ = tZ
            self.locale = locale }
    }
    
    internal static var iso8601: [String: ISO8601DateFormatter] = [:]
    internal static var locale: [Key: DateFormatter] = [:]

    private static let lock: ReadWriteLock = .init()
}

// MARK: Internal implementations

internal extension Timestamp.ReferenceBase {
    var interval: Double {
         switch self {
             case .now: return Date().timeIntervalSinceReferenceDate
             case .unixEpoch: return -1 * Date.timeIntervalBetween1970AndReferenceDate
             case .referenceDate: return 0
             case .distantFuture: return Date.distantFuture.timeIntervalSinceReferenceDate
             case .distantPast: return Date.distantPast.timeIntervalSinceReferenceDate
         }
     }

     static func fault(_ str: String) -> TemplateData {
         .error("\(str) is not a valid reference base; must be one of \(Self.terse)]")
     }
}

internal extension DateFormatters {
    static subscript(timezone: String, fractional: Bool) -> ISO8601DateFormatter? {
        get { lock.readWithLock { iso8601[timezone + (fractional ? "T" : "F")] } }
        set { lock.writeWithLock { iso8601[timezone + (fractional ? "T" : "F")] = newValue } }
    }
    
    static subscript(key: Key) -> DateFormatter? {
        get { lock.readWithLock { locale[key] } }
        set { lock.writeWithLock { locale[key] = newValue } }
    }
    
    static var base: Date {
        Date(timeIntervalSinceReferenceDate: Timestamp.referenceBase.interval) }
    
    static var now: () -> TemplateData = {
        Timestamp().evaluate(.init(["now", Timestamp.referenceBase.templateData], ["since": 1])) }
    
    static func timeZone(_ from: String) -> TimeZone? {
        if let tz = TimeZone(abbreviation: from) {
            return tz }
        else if let tz = TimeZone(identifier: from) {
            return tz }
        return nil
    }
    
    static func evaluate(_ params: CallValues, fixed: Bool) -> TemplateData {
        let f = params[1].string!
        let z = params[2].string!
        let l = params[3].string
        let key = Key(f, z, l)
        var formatter = Self[key]
        
        let timestamp = params[0]
        let interval: Double
                
        if timestamp.isNumeric { interval = timestamp.double! }
        else {
            guard let t = Timestamp.ReferenceBase(rawValue: timestamp.string!) else {
                return Timestamp.ReferenceBase.fault(timestamp.string!) }
            interval = t.interval
        }
        
        if formatter == nil {
            guard let zone = TimeZone(identifier: z) else {
                return .error("\(z) is not a valid time zone identifier") }
            if let l = l, !Locale.availableIdentifiers.contains(l) {
                return .error("\(l) is not a known locale identifier") }
            formatter = DateFormatter()
            formatter!.dateFormat = fixed ? f : DateFormatter.dateFormat(fromTemplate: f, options: 0, locale: Locale(identifier: l!))
            formatter!.timeZone = zone
            if !fixed { formatter!.locale = Locale(identifier: l!) }
            Self[key] = formatter
        }
        
        return .string(formatter!.string(from: base.addingTimeInterval(interval)))
    }
}
