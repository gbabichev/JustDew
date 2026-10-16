import Foundation

enum DewPointFormatters {
    static func temperature(_ measurement: Measurement<UnitTemperature>, locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.numberFormatter.maximumFractionDigits = 0
        formatter.numberFormatter.minimumFractionDigits = 0
        formatter.unitOptions = .providedUnit
        return formatter.string(from: measurement.converted(to: UnitTemperature(forLocale: locale, usage: .weather)))
    }

    static func temperatureValue(_ measurement: Measurement<UnitTemperature>, locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        let value = measurement.converted(to: UnitTemperature(forLocale: locale, usage: .weather)).value
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value.rounded()))"
    }

    static func temperatureRange(
        low: Measurement<UnitTemperature>,
        high: Measurement<UnitTemperature>,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let lowValue = temperatureValue(low, locale: locale)
        let highValue = temperatureValue(high, locale: locale)
        guard lowValue != highValue else { return temperature(high, locale: locale) }

        return "\(lowValue)-\(temperature(high, locale: locale))"
    }

    static func percent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value * 100))%"
    }

    static func updatedTime(_ date: Date, timeZone: TimeZone? = nil, includesDate: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone ?? .current
        formatter.dateStyle = includesDate ? .short : .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func hourLabel(_ date: Date, timeZone: TimeZone? = nil) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone ?? .current
        formatter.dateStyle = .none
        formatter.dateFormat = DateFormatter.dateFormat(
            fromTemplate: "ha",
            options: 0,
            locale: .current
        )
        return formatter.string(from: date)
    }

    static func weekdayLabel(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        }

        let formatter = DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = DateFormatter.dateFormat(
            fromTemplate: "EEE",
            options: 0,
            locale: .current
        )
        return formatter.string(from: date)
    }

    static func forecastDayLabel(_ date: Date, relativeTo reference: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: reference) { return String(localized: "Today") }
        let formatter = DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "EEE", options: 0, locale: .current)
        return formatter.string(from: date)
    }
}
