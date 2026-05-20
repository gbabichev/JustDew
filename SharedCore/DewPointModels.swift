import CoreLocation
import Foundation

enum DewPointLocationMode: String, Codable, Sendable {
    case current
    case manual

    var title: String {
        switch self {
        case .current:
            "Current Location"
        case .manual:
            "Manual Location"
        }
    }
}

struct DewPointLocation: Codable, Equatable, Sendable {
    var mode: DewPointLocationMode
    var name: String
    var shortName: String? = nil
    var latitude: Double
    var longitude: Double
    var savedAt: Date

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var compactDisplayName: String {
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

    var hasSpecificDisplayName: Bool {
        compactDisplayName != "Current Location"
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

    var dewPoint: Measurement<UnitTemperature> {
        Measurement(value: dewPointCelsius, unit: .celsius)
    }

    var temperature: Measurement<UnitTemperature> {
        Measurement(value: temperatureCelsius, unit: .celsius)
    }
}

enum DewPointError: LocalizedError {
    case locationUnavailable
    case permissionDenied
    case widgetLocationUnavailable
    case geocodingNoResults
    case locationSearchUnavailable
    case missingConfiguredLocation
    case networkUnavailable
    case weatherUnavailable
    case weatherKitAuthentication

    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            "Location is unavailable."
        case .permissionDenied:
            "Location permission is not enabled."
        case .widgetLocationUnavailable:
            "Widget location is not enabled."
        case .geocodingNoResults:
            "No matching location was found. Try a city and state."
        case .locationSearchUnavailable:
            "Location search is temporarily unavailable. Check your connection and try again."
        case .missingConfiguredLocation:
            "Choose a location."
        case .networkUnavailable:
            "Network connection appears to be offline."
        case .weatherUnavailable:
            "Weather data is temporarily unavailable. Try again in a moment."
        case .weatherKitAuthentication:
            "WeatherKit setup is incomplete for this bundle ID. In Apple Developer Identifiers, enable WeatherKit in App Services and App Capabilities, then clean and rebuild."
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
            return "Something went wrong. Try again."
        }

        return rawMessage
    }
}
