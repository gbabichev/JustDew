import Foundation

enum DewPointFormatters {
    static func temperature(_ measurement: Measurement<UnitTemperature>) -> String {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 0
        formatter.numberFormatter.minimumFractionDigits = 0
        formatter.unitOptions = .providedUnit
        return formatter.string(from: measurement.converted(to: preferredTemperatureUnit))
    }

    static func temperatureValue(_ measurement: Measurement<UnitTemperature>) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        let value = measurement.converted(to: preferredTemperatureUnit).value
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value.rounded()))"
    }

    static func temperatureRange(
        low: Measurement<UnitTemperature>,
        high: Measurement<UnitTemperature>
    ) -> String {
        let lowValue = temperatureValue(low)
        let highValue = temperatureValue(high)
        guard lowValue != highValue else { return temperature(high) }

        return "\(lowValue)-\(temperature(high))"
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

    private static var preferredTemperatureUnit: UnitTemperature {
        let regionCode: String?
        if #available(iOS 16, macOS 13, watchOS 9, *) {
            regionCode = Locale.current.region?.identifier
        } else {
            regionCode = Locale.current.regionCode
        }

        switch regionCode {
        case "US", "BS", "BZ", "KY", "PW":
            return .fahrenheit
        default:
            return .celsius
        }
    }
}
