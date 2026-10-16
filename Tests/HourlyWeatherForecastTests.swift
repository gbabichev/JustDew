import Foundation

// Compile with DewPointModels, HourlyWeatherForecast, DewPointFormatters,
// DewPointConfiguration, and DewPointStore. Runs without WeatherKit or a simulator.
@main
struct HourlyWeatherForecastTests {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let now = ISO8601DateFormatter().date(from: "2026-10-16T00:30:00Z")!
        let start = calendar.startOfDay(for: now)
        let location = DewPointLocation(mode: .manual, name: "Tokyo", latitude: 35, longitude: 139,
            savedAt: now, timeZoneIdentifier: calendar.timeZone.identifier)
        let details = DewPointHourlyWeather(precipitationChance: 0.4, windSpeedMetersPerSecond: 10,
            windGustMetersPerSecond: 14, windDirection: "northwest", uvIndex: 0, uvCategory: "low",
            condition: "Rain", symbolName: "cloud.rain")
        var reading = DewPointReading(location: location, dewPointCelsius: 12, temperatureCelsius: 20,
            humidity: 0.5, condition: "Clear", symbolName: "sun.max", observedAt: now, fetchedAt: now)
        reading.dailyForecast = (0..<48).map { hour in
            DewPointForecastPoint(date: start.addingTimeInterval(Double(hour) * 3_600),
                dewPointCelsius: 12, temperatureCelsius: 20, humidity: 0.5, weather: details)
        }
        let forecast = HourlyWeatherForecast(reading: reading, referenceDate: now)
        precondition(forecast.hasDetails && forecast.days.count == 2)
        precondition(forecast.days[0].date == start)
        let hours = forecast.days.flatMap(\.hours)
        precondition(hours.count == 25, "A rolling 24 hours includes two partial endpoint hours")
        precondition(hours.first!.start == start.addingTimeInterval(9 * 3_600))
        precondition(hours.last!.start == start.addingTimeInterval(33 * 3_600))
        precondition(hours.allSatisfy { $0.end > now && $0.start < now.addingTimeInterval(86_400) })
        let decoded = try JSONDecoder().decode(DewPointReading.self, from: JSONEncoder().encode(reading))
        precondition(decoded == reading && decoded.dailyForecastPoints[0].weather?.uvIndex == 0)

        // Existing cached forecast points still decode with no hourly-details payload.
        let legacyPoint = DewPointForecastPoint(date: now, dewPointCelsius: 12, temperatureCelsius: 20, humidity: 0.5)
        let legacyData = try JSONEncoder().encode(legacyPoint)
        let legacyJSON = try JSONSerialization.jsonObject(with: legacyData) as! [String: Any]
        precondition(legacyJSON["weather"] == nil)
        let legacyDecoded = try JSONDecoder().decode(DewPointForecastPoint.self, from: legacyData)
        precondition(legacyDecoded.weather == nil)
        var legacy = reading
        legacy.dailyForecast = [legacyPoint]
        precondition(!HourlyWeatherForecast(reading: legacy, referenceDate: now).hasDetails)

        // A current snapshot replaces one hourly row; it doesn't create an extra hour.
        var current = reading.dailyForecastPoints[9]
        current.date = now
        current.weather?.precipitationChance = 0.8
        reading.dailyForecast?.append(current)
        let replaced = HourlyWeatherForecast(reading: reading, referenceDate: now).days.flatMap(\.hours)
        precondition(replaced.count == 25 && replaced[0].point.weather?.precipitationChance == 0.8)

        // Repeated local 1 AM hours have distinct identities across the autumn clock change.
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let fall = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        reading.location.timeZoneIdentifier = calendar.timeZone.identifier
        reading.dailyForecast = (0..<25).map { offset in
            DewPointForecastPoint(date: fall.addingTimeInterval(Double(offset) * 3_600),
                dewPointCelsius: 12, temperatureCelsius: 20, humidity: 0.5, weather: details)
        }
        let fallHours = HourlyWeatherForecast(reading: reading, referenceDate: fall).days.flatMap(\.hours)
        precondition(fallHours.count == 24)
        precondition(calendar.component(.hour, from: fallHours[1].start) == 1)
        precondition(calendar.component(.hour, from: fallHours[2].start) == 1)
        precondition(fallHours[1].id != fallHours[2].id)

        // Persisting and merging fresh data retains all detail fields.
        let suite = "JustDewHourlyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DewPointStore(defaults: defaults)
        reading.observedAt = fall
        reading.fetchedAt = fall
        store.saveReading(reading)
        precondition(store.loadReading()?.dailyForecastPoints.first?.weather == details)
        reading.dailyForecast?[0].weather?.windSpeedMetersPerSecond = 5
        store.saveReading(reading)
        precondition(store.loadReading()?.dailyForecastPoints.first?.weather?.windSpeedMetersPerSecond == 5)

        // Wind units follow the system locale, with invalid values left unknown.
        func compact(_ value: String) -> String { value.filter { !$0.isWhitespace } }
        precondition(compact(DewPointFormatters.windSpeed(10, locale: Locale(identifier: "en_US"))) == "22mph")
        precondition(compact(DewPointFormatters.windSpeed(10, locale: Locale(identifier: "fr_FR"))) == "36km/h")
        precondition(DewPointFormatters.windSpeed(.nan) == "—")
        precondition(DewPointFormatters.windSpeed(-1) == "—")
        print("Hourly weather detail tests passed")
    }
}
