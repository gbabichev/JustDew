import CoreLocation
import Foundation
import WeatherKit

enum DewPointWeatherClient {
    static func reading(for location: DewPointLocation) async throws -> DewPointReading {
        do {
            let current = try await WeatherService.shared.weather(for: location.clLocation, including: .current)

            return DewPointReading(
                location: location,
                dewPointCelsius: current.dewPoint.converted(to: .celsius).value,
                temperatureCelsius: current.temperature.converted(to: .celsius).value,
                humidity: current.humidity,
                condition: current.condition.description,
                symbolName: current.symbolName,
                observedAt: current.date,
                fetchedAt: Date()
            )
        } catch {
            if error.isWeatherKitAuthenticationFailure {
                throw DewPointError.weatherKitAuthentication
            }
            throw error
        }
    }
}

private extension Error {
    var isWeatherKitAuthenticationFailure: Bool {
        let nsError = self as NSError
        let diagnosticText = [
            nsError.domain,
            nsError.localizedDescription
        ].joined(separator: " ")

        if diagnosticText.contains("WDSJWTAuthenticatorServiceListener")
            || diagnosticText.contains("WDSJWTAuthenticatorService")
            || diagnosticText.contains("com.apple.weatherkit.authservice") {
            return true
        }

        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return underlyingError.isWeatherKitAuthenticationFailure
        }

        return false
    }
}
