import Foundation

enum DewPointConfiguration {
    static let appGroupIdentifier = "group.com.georgebabichev.JustDew"
    static let appWidgetKind = "JustDewWidget"
    static let watchWidgetKind = "JustDewWatch"
    static let refreshInterval: TimeInterval = 30 * 60
    static let appleWeatherTrademark = "\u{F8FF} Weather"
    static let appleWeatherLegalAttributionURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!
}
