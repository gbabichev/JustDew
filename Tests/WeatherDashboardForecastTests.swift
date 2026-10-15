import Foundation

// Compile with DewPointModels, DewPointConfiguration, DewPointStore, and WeatherDashboardForecast.
@main
struct WeatherDashboardForecastTests {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let observed = ISO8601DateFormatter().date(from: "2026-10-15T15:30:00Z")!
        let start = calendar.startOfDay(for: observed)
        let location = DewPointLocation(mode: .manual, name: "Tokyo", latitude: 35.68, longitude: 139.69,
                                        savedAt: observed, timeZoneIdentifier: calendar.timeZone.identifier)
        var reading = DewPointReading(location: location, dewPointCelsius: 12, temperatureCelsius: 20,
                                      humidity: 0.5, condition: "Clear", symbolName: "sun.max",
                                      observedAt: observed, fetchedAt: observed)

        // Simulate a pre-dashboard cache, including a location without a stored timezone.
        var legacy = reading
        legacy.location.timeZoneIdentifier = nil
        let oldData = try JSONEncoder().encode(legacy)
        let object = try JSONSerialization.jsonObject(with: oldData) as! [String: Any]
        precondition(object["dailyWeather"] == nil && object["apparentTemperatureCelsius"] == nil)
        let decoded = try JSONDecoder().decode(DewPointReading.self, from: oldData)
        precondition(decoded.temperatureCelsius == 20 && decoded.dailyWeather == nil)
        precondition(decoded.location.timeZoneIdentifier == nil)

        reading.dailyWeather = (0..<10).map { offset in
            WeatherForecastDay(date: calendar.date(byAdding: .day, value: offset, to: start)!,
                               lowTemperatureCelsius: Double(offset), highTemperatureCelsius: Double(offset + 10),
                               condition: "Clear", symbolName: "sun.max", precipitationChance: 0.2)
        }
        reading.apparentTemperatureCelsius = 19
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start)!
        reading.dailyForecast = [DewPointForecastPoint(date: observed, dewPointCelsius: 12,
                                                       temperatureCelsius: 20, humidity: 0.5)]
            + (0..<24).map { hour in
                DewPointForecastPoint(date: calendar.date(byAdding: .hour, value: hour, to: tomorrow)!,
                                      dewPointCelsius: Double(hour), temperatureCelsius: 20, humidity: 0.5)
            }
        let forecast = WeatherDashboardForecast(reading: reading, referenceDate: observed)
        precondition(forecast.days.count == 10)
        precondition(forecast.days[0].date == start)
        precondition(calendar.component(.day, from: forecast.days[0].date) == 16, "Tokyo's Today differs from UTC")
        precondition(forecast.days[0].weather?.lowTemperatureCelsius == 0)
        precondition(forecast.days[0].hasPartialDewPoint)
        precondition(forecast.days[1].lowDewPointCelsius == 0 && forecast.days[1].highDewPointCelsius == 23)
        precondition(!forecast.days[1].hasPartialDewPoint)
        precondition(forecast.days[2].lowDewPointCelsius == nil, "Missing forecast must not become zero")
        precondition(forecast.temperatureScale.fraction(for: 0) == 0)
        precondition(forecast.temperatureScale.fraction(for: 19) == 1)
        precondition(WeatherRangeScale(values: [7, 7]).fraction(for: 7) == 0.5)
        precondition(WeatherRangeScale(values: [.nan, .infinity]).fraction(for: .nan) == 0)
        let roundTrip = try JSONDecoder().decode(DewPointReading.self, from: JSONEncoder().encode(reading))
        precondition(roundTrip == reading)

        // Local calendar days and repeated hours survive the fall daylight-saving transition.
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let fallStart = newYork.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let fallEnd = newYork.date(byAdding: .day, value: 1, to: fallStart)!
        precondition(newYork.dateComponents([.hour], from: fallStart, to: fallEnd).hour == 25)
        var fall = reading
        fall.location.timeZoneIdentifier = newYork.timeZone.identifier
        fall.observedAt = fallStart
        fall.dailyForecast = (0..<25).map { hour in
            DewPointForecastPoint(date: fallStart.addingTimeInterval(Double(hour) * 3_600),
                                  dewPointCelsius: Double(hour), temperatureCelsius: 20, humidity: 0.5)
        }
        precondition(!WeatherDashboardForecast(reading: fall, referenceDate: fallStart).days[0].hasPartialDewPoint)
        let suite = "JustDewDashboardTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DewPointStore(defaults: defaults)
        store.saveReading(fall)
        store.saveReading(fall)
        precondition(store.loadReading()?.dailyForecastPoints.count == 25, "Do not merge the two 1 AM hours together")
        precondition(store.loadReading()?.dailyWeather == fall.dailyWeather)
        var missingHour = fall
        missingHour.dailyForecast?.remove(at: 12)
        precondition(WeatherDashboardForecast(reading: missingHour, referenceDate: fallStart).days[0].hasPartialDewPoint)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: observed)!
        precondition(WeatherDashboardForecast(reading: reading, referenceDate: nextDay).days[0].date == tomorrow,
                     "A stale reading must not label yesterday as Today")
        print("Weather dashboard forecast tests passed")
    }
}
