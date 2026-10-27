import CoreLocation
import Foundation
import WeatherKit

nonisolated enum DewPointWeatherClient {
    @concurrent
    static func reading(for location: DewPointLocation) async throws -> DewPointReading {
        do {
            var resolvedLocation = location
            if resolvedLocation.timeZoneIdentifier == nil {
                resolvedLocation.timeZoneIdentifier = await LocationSearchService.timeZoneIdentifier(for: location.clLocation)
            }
            var calendar = Calendar.current
            if let identifier = resolvedLocation.timeZoneIdentifier, let timeZone = TimeZone(identifier: identifier) {
                calendar.timeZone = timeZone
            }
            let requestDate = Date()
            let forecastRange = DewPointConfiguration.forecastDateRange(for: requestDate, calendar: calendar)
            let (current, hourly, daily) = try await WeatherService.shared.weather(
                for: location.clLocation,
                including: .current,
                // Include earlier hours today so both timelines can show the full local day.
                .hourly(startDate: forecastRange.lowerBound, endDate: forecastRange.upperBound),
                .daily
            )
            let currentHour = hourly.forecast.first {
                $0.date <= current.date && current.date < $0.date.addingTimeInterval(3_600)
            }
            let currentForecastPoint = DewPointForecastPoint(
                date: current.date,
                dewPointCelsius: current.dewPoint.converted(to: .celsius).value,
                temperatureCelsius: current.temperature.converted(to: .celsius).value,
                humidity: current.humidity,
                weather: currentHour.map { hourlyDetails(for: $0) }
            )

            return DewPointReading(
                location: resolvedLocation,
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
                    currentPoint: currentForecastPoint,
                    calendar: calendar
                ),
                apparentTemperatureCelsius: current.apparentTemperature.converted(to: .celsius).value,
                dailyWeather: daily.forecast.filter { forecastRange.contains($0.date) }.map { day in
                    WeatherForecastDay(
                        date: day.date,
                        lowTemperatureCelsius: day.lowTemperature.converted(to: .celsius).value,
                        highTemperatureCelsius: day.highTemperature.converted(to: .celsius).value,
                        condition: day.condition.description,
                        symbolName: day.symbolName,
                        precipitationChance: day.precipitationChance
                    )
                }
            )
        } catch {
            if error.isWeatherKitAuthenticationFailure {
                throw DewPointError.weatherKitAuthentication
            }
            throw error
        }
    }

    private static func hourlyDetails(for hour: HourWeather) -> DewPointHourlyWeather {
        DewPointHourlyWeather(
            precipitationChance: hour.precipitationChance,
            windSpeedMetersPerSecond: hour.wind.speed.converted(to: .metersPerSecond).value,
            windGustMetersPerSecond: hour.wind.gust?.converted(to: .metersPerSecond).value,
            windDirection: hour.wind.compassDirection.rawValue,
            uvIndex: hour.uvIndex.value,
            uvCategory: hour.uvIndex.category.rawValue,
            condition: hour.condition.description,
            symbolName: hour.symbolName
        )
    }

    private static func dailyForecast(
        from hourlyForecast: [HourWeather],
        observedAt: Date,
        currentPoint: DewPointForecastPoint,
        calendar: Calendar
    ) -> [DewPointForecastPoint] {
        let forecastInterval = DewPointConfiguration.forecastDateRange(for: observedAt, calendar: calendar)

        let forecastPoints = hourlyForecast
            .filter { forecastInterval.contains($0.date) }
            .sorted { $0.date < $1.date }
            .map { hour in
                DewPointForecastPoint(
                    date: hour.date,
                    dewPointCelsius: hour.dewPoint.converted(to: .celsius).value,
                    temperatureCelsius: hour.temperature.converted(to: .celsius).value,
                    humidity: hour.humidity,
                    weather: hourlyDetails(for: hour)
                )
            }

        return (forecastPoints + [currentPoint])
            .filter { forecastInterval.contains($0.date) }
            .uniquedByHour(calendar: calendar)
            .sorted { $0.date < $1.date }
    }


}

private extension Array where Element == DewPointForecastPoint {
    nonisolated func uniquedByHour(calendar: Calendar) -> [DewPointForecastPoint] {

        return reduce(into: [Date: DewPointForecastPoint]()) { partialResult, point in
            let key = calendar.startOfHour(for: point.date)
            partialResult[key] = point
        }
        .values
        .sorted { $0.date < $1.date }
    }
}

private extension Calendar {
    nonisolated func startOfHour(for date: Date) -> Date {
        dateInterval(of: .hour, for: date)?.start ?? date
    }
}

private extension Error {
    nonisolated var isWeatherKitAuthenticationFailure: Bool {
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
