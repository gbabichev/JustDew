import Foundation

nonisolated enum DewPointConfiguration {
    static let appGroupIdentifier = "group.com.georgebabichev.JustDew"
    static let appWidgetKind = "JustDewWidget"
    static let watchWidgetKind = "JustDewWatch"
    // WeatherKit supplies ten forecast days, including today.
    static let forecastDayCount = 10

    static func forecastDateRange(for date: Date, calendar: Calendar = .current) -> Range<Date> {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: forecastDayCount, to: start)
            ?? start.addingTimeInterval(Double(forecastDayCount) * 86_400)
        return start..<end
    }

    static let refreshInterval: TimeInterval = 30 * 60
    static let appleWeatherTrademark = "\u{F8FF} Weather"
    static let appleWeatherLegalAttributionURL = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!
}
