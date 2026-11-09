import CoreLocation
import Foundation
import WeatherKit

enum DewPointLocationMode: String, Codable, Sendable {
    case current
    case manual

    var title: String {
        switch self {
        case .current:
            String(localized: "Current Location")
        case .manual:
            String(localized: "Manual Location")
        }
    }
}

struct DewPointLocation: Codable, Equatable, Sendable, Identifiable {
    // Current Location keeps its identity as the device moves.
    var id: String {
        mode == .current ? "current" : String(format: "%.6f,%.6f", latitude, longitude)
    }

    var mode: DewPointLocationMode
    var name: String
    var shortName: String? = nil
    var latitude: Double
    var longitude: Double
    var savedAt: Date
    var timeZoneIdentifier: String? = nil

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var compactDisplayName: String {
        if name == "Current Location" && shortName == nil { return String(localized: "Current Location") }
        if let compactName = cityStateName(from: shortName) ?? cityStateName(from: name) {
            return compactName
        }

        if let shortName = shortName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !shortName.isEmpty {
            return shortName
        }

        let components = locationNameComponents(from: name)
        return components.first ?? name
    }

    var widgetDisplayName: String {
        compactDisplayName
    }

    /// A city is the same city wherever in it the device is, so pinning compares names, not coordinates.
    var cityKey: String {
        compactDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var hasSpecificDisplayName: Bool {
        !(name == "Current Location" && shortName == nil)
    }

    private func cityStateName(from value: String?) -> String? {
        let components = locationNameComponents(from: value)
        if let stateIndex = components.firstIndex(where: { component in
            component.range(of: #"^[A-Z]{2}(?:\s+\d{5})?$"#, options: .regularExpression) != nil
        }), stateIndex > components.startIndex {
            let city = components[components.index(before: stateIndex)]
            let state = components[stateIndex]
                .split(separator: " ")
                .first
                .map(String.init) ?? components[stateIndex]
            return "\(city), \(state)"
        }

        return nil
    }

    private func locationNameComponents(from value: String?) -> [String] {
        (value ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

struct DewPointReading: Codable, Equatable, Sendable {
    var location: DewPointLocation
    var dewPointCelsius: Double
    var temperatureCelsius: Double
    var humidity: Double
    var condition: String
    var symbolName: String
    var observedAt: Date
    var fetchedAt: Date
    var dailyForecast: [DewPointForecastPoint]? = nil
    var apparentTemperatureCelsius: Double? = nil
    var dailyWeather: [WeatherForecastDay]? = nil
    var conditionCode: String? = nil

    var localizedCondition: String {
        conditionCode.flatMap { WeatherCondition(rawValue: $0) }?.description ?? condition
    }

    var forecastCalendar: Calendar {
        var calendar = Calendar.current
        if let identifier = location.timeZoneIdentifier, let timeZone = TimeZone(identifier: identifier) {
            calendar.timeZone = timeZone
        }
        return calendar
    }

    var dewPoint: Measurement<UnitTemperature> {
        Measurement(value: dewPointCelsius, unit: .celsius)
    }

    var temperature: Measurement<UnitTemperature> {
        Measurement(value: temperatureCelsius, unit: .celsius)
    }

    /// Daily range matching the displayed observation in the location's own time zone.
    var observedDayWeather: WeatherForecastDay? {
        dailyWeather?.first {
            forecastCalendar.isDate($0.date, inSameDayAs: observedAt)
                && $0.lowTemperatureCelsius.isFinite && $0.highTemperatureCelsius.isFinite
                && $0.lowTemperatureCelsius <= $0.highTemperatureCelsius
        }
    }

    var observedDayDewPointRange: ClosedRange<Double>? {
        let values = dailyForecastPoints.filter {
            forecastCalendar.isDate($0.date, inSameDayAs: observedAt)
        }.map(\.dewPointCelsius).filter(\.isFinite)
        guard let low = values.min(), let high = values.max() else { return nil }
        return low...high
    }

    var dailyForecastPoints: [DewPointForecastPoint] {
        dailyForecast ?? []
    }
}

struct WeatherForecastDay: Codable, Equatable, Sendable, Identifiable {
    var date: Date
    var lowTemperatureCelsius: Double
    var highTemperatureCelsius: Double
    var condition: String
    var symbolName: String
    var precipitationChance: Double
    var conditionCode: String? = nil

    var localizedCondition: String {
        conditionCode.flatMap { WeatherCondition(rawValue: $0) }?.description ?? condition
    }

    var id: Date { date }
}

struct DewPointForecastPoint: Codable, Equatable, Sendable, Identifiable {
    var date: Date
    var dewPointCelsius: Double
    var temperatureCelsius: Double
    var humidity: Double
    var weather: DewPointHourlyWeather? = nil

    var id: Date {
        date
    }

    var dewPoint: Measurement<UnitTemperature> {
        Measurement(value: dewPointCelsius, unit: .celsius)
    }

    var temperature: Measurement<UnitTemperature> {
        Measurement(value: temperatureCelsius, unit: .celsius)
    }
}

enum DewPointError: LocalizedError {
    case locationUnavailable
    case usingLastKnownLocation
    case permissionDenied
    case widgetLocationUnavailable
    case geocodingNoResults
    case locationSearchUnavailable
    case missingConfiguredLocation
    case networkUnavailable
    case weatherUnavailable
    case weatherKitAuthentication

    /// The user must change a setting; a stale reading would hide that.
    var isLocationPermissionProblem: Bool {
        self == .permissionDenied || self == .widgetLocationUnavailable
    }

    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            String(localized: "Location is unavailable.")
        case .usingLastKnownLocation:
            String(localized: "Using your last known location")
        case .permissionDenied:
            String(localized: "Location permission is not enabled.")
        case .widgetLocationUnavailable:
            String(localized: "Widget location is not enabled.")
        case .geocodingNoResults:
            String(localized: "No matching location was found. Try a city and state.")
        case .locationSearchUnavailable:
            String(localized: "Location search is temporarily unavailable. Check your connection and try again.")
        case .missingConfiguredLocation:
            String(localized: "Choose a location.")
        case .networkUnavailable:
            String(localized: "Network connection appears to be offline.")
        case .weatherUnavailable:
            String(localized: "Weather data is temporarily unavailable. Try again in a moment.")
        case .weatherKitAuthentication:
            String(localized: "WeatherKit setup is incomplete for this bundle ID. In Apple Developer Identifiers, enable WeatherKit in App Services and App Capabilities, then clean and rebuild.")
        }
    }
}

extension Error {
    var dewPointDisplayMessage: String {
        if let dewPointError = self as? DewPointError,
           let message = dewPointError.errorDescription {
            return message
        }

        let nsError = self as NSError

        switch nsError.domain {
        case "MKErrorDomain":
            if nsError.code == 4 {
                return DewPointError.geocodingNoResults.localizedDescription
            }
            return DewPointError.locationSearchUnavailable.localizedDescription
        case NSURLErrorDomain:
            return DewPointError.networkUnavailable.localizedDescription
        default:
            break
        }

        if nsError.domain.localizedCaseInsensitiveContains("weather")
            || nsError.domain.localizedCaseInsensitiveContains("WeatherDaemon") {
            return DewPointError.weatherUnavailable.localizedDescription
        }

        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return underlyingError.dewPointDisplayMessage
        }

        let rawMessage = nsError.localizedDescription
        if rawMessage.hasPrefix("The operation couldn") {
            return String(localized: "Something went wrong. Try again.")
        }

        return rawMessage
    }
}
