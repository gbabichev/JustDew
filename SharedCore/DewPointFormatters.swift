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

    static func windSpeed(_ metersPerSecond: Double, locale: Locale = .autoupdatingCurrent) -> String {
        guard metersPerSecond.isFinite, metersPerSecond >= 0 else { return "—" }
        let formatter = MeasurementFormatter()
        formatter.locale = locale
        formatter.numberFormatter.maximumFractionDigits = 0
        formatter.numberFormatter.minimumFractionDigits = 0
        formatter.unitOptions = .providedUnit
        let speed = Measurement(value: metersPerSecond, unit: UnitSpeed.metersPerSecond)
        return formatter.string(from: speed.converted(to: UnitSpeed(forLocale: locale, usage: .wind)))
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

    static func timeZoneLabel(_ date: Date, timeZone: TimeZone) -> String {
        timeZone.abbreviation(for: date) ?? timeZone.identifier
    }

    static func hourlyDetailsTime(_ date: Date, referenceDate: Date, timeZone: TimeZone) -> String {
        let label = hourLabel(date, timeZone: timeZone)
        let offset = timeZone.secondsFromGMT(for: date)
        let crossesTransition = timeZone.secondsFromGMT(for: date.addingTimeInterval(-3_600)) != offset
            || timeZone.secondsFromGMT(for: date.addingTimeInterval(3_600)) != offset
        // Identify both occurrences of a repeated hour and hours outside the subtitle's offset.
        guard crossesTransition || offset != timeZone.secondsFromGMT(for: referenceDate) else { return label }
        return "\(label) \(timeZoneLabel(date, timeZone: timeZone))"
    }

    static func forecastDayLabel(_ date: Date, relativeTo reference: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: reference) { return String(localized: "Today") }
        let formatter = DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "EEE", options: 0, locale: .current)
        return formatter.string(from: date)
    }
}
