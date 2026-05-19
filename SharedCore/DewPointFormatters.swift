import Foundation

enum DewPointFormatters {
    static func temperature(_ measurement: Measurement<UnitTemperature>) -> String {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 0
        formatter.numberFormatter.minimumFractionDigits = 0
        formatter.unitOptions = .providedUnit
        return formatter.string(from: measurement.converted(to: preferredTemperatureUnit))
    }

    static func percent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value * 100))%"
    }

    static func updatedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
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
