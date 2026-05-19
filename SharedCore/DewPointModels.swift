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

    var widgetDisplayName: String {
        if let shortName = shortName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !shortName.isEmpty {
            return shortName
        }

        let components = name
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let stateIndex = components.firstIndex(where: { component in
            component.range(of: #"^[A-Z]{2}$"#, options: .regularExpression) != nil
        }), stateIndex > components.startIndex {
            return "\(components[components.index(before: stateIndex)]), \(components[stateIndex])"
        }

        return components.first ?? name
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
    case missingConfiguredLocation
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
            "No matching location was found."
        case .missingConfiguredLocation:
            "Choose a location in JustDew."
        case .weatherKitAuthentication:
            "WeatherKit setup is incomplete for this bundle ID. In Apple Developer Identifiers, enable WeatherKit in App Services and App Capabilities, then clean and rebuild."
        }
    }
}
