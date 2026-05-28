import CoreLocation
import Foundation
import WeatherKit

enum DewPointWeatherClient {
    static func reading(for location: DewPointLocation) async throws -> DewPointReading {
        do {
            let (current, hourly) = try await WeatherService.shared.weather(
                for: location.clLocation,
                including: .current,
                .hourly
            )
            let currentForecastPoint = DewPointForecastPoint(
                date: current.date,
                dewPointCelsius: current.dewPoint.converted(to: .celsius).value,
                temperatureCelsius: current.temperature.converted(to: .celsius).value,
                humidity: current.humidity
            )

            return DewPointReading(
                location: location,
                dewPointCelsius: current.dewPoint.converted(to: .celsius).value,
                temperatureCelsius: current.temperature.converted(to: .celsius).value,
                humidity: current.humidity,
                condition: current.condition.description,
                symbolName: current.symbolName,
                observedAt: current.date,
                fetchedAt: Date(),
                dailyForecast: dailyForecast(
                    from: hourly.forecast,
                    observedAt: current.date,
                    currentPoint: currentForecastPoint
                )
            )
        } catch {
            if error.isWeatherKitAuthenticationFailure {
                throw DewPointError.weatherKitAuthentication
            }
            throw error
        }
    }

    private static func dailyForecast(
        from hourlyForecast: [HourWeather],
        observedAt: Date,
        currentPoint: DewPointForecastPoint
    ) -> [DewPointForecastPoint] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: observedAt)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let dayInterval = dayStart..<dayEnd

        let forecastPoints = hourlyForecast
            .filter { dayInterval.contains($0.date) }
            .sorted { $0.date < $1.date }
            .map { hour in
                DewPointForecastPoint(
                    date: hour.date,
                    dewPointCelsius: hour.dewPoint.converted(to: .celsius).value,
                    temperatureCelsius: hour.temperature.converted(to: .celsius).value,
                    humidity: hour.humidity
                )
            }

        return (forecastPoints + [currentPoint])
            .filter { dayInterval.contains($0.date) }
            .uniquedByHour()
            .sorted { $0.date < $1.date }
    }
}

private extension Array where Element == DewPointForecastPoint {
    func uniquedByHour() -> [DewPointForecastPoint] {
        let calendar = Calendar.current

        return reduce(into: [Date: DewPointForecastPoint]()) { partialResult, point in
            let key = calendar.startOfHour(for: point.date)
            partialResult[key] = point
        }
        .values
        .sorted { $0.date < $1.date }
    }
}

private extension Calendar {
    func startOfHour(for date: Date) -> Date {
        let components = dateComponents([.year, .month, .day, .hour], from: date)
        return self.date(from: components) ?? date
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
