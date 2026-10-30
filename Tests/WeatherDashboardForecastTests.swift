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
        // Early East Coast mornings can have hourly data for ten days, but only nine daily summaries.
        let earlyMorning = ISO8601DateFormatter().date(from: "2026-10-27T10:14:00Z")!
        let earlyStart = newYork.startOfDay(for: earlyMorning)
        var early = reading
        early.location.timeZoneIdentifier = newYork.timeZone.identifier
        early.observedAt = earlyMorning
        let dates = (0..<10).map { newYork.date(byAdding: .day, value: $0, to: earlyStart)! }
        early.dailyForecast = dates.map {
            DewPointForecastPoint(date: $0.addingTimeInterval(12 * 3600), dewPointCelsius: 10,
                                  temperatureCelsius: 20, humidity: 0.5)
        }
        early.dailyWeather = dates.prefix(9).map {
            WeatherForecastDay(date: $0, lowTemperatureCelsius: 10, highTemperatureCelsius: 20,
                               condition: "Clear", symbolName: "sun.max", precipitationChance: 0)
        }
        let earlyForecast = WeatherDashboardForecast(reading: early, referenceDate: earlyMorning)
        precondition(earlyForecast.weatherDays.map(\.date) == Array(dates.prefix(9)),
                     "Do not display an unknown tenth weather row")
        precondition(earlyForecast.dewPointDays.map(\.date) == dates,
                     "Available dew point data must survive a missing daily weather summary")
        precondition(earlyForecast.dewPointDays.allSatisfy(\.hasPartialDewPoint),
                     "Partial numeric ranges are still real forecast data")

        // As more data arrives, the previously missing day becomes visible automatically.
        early.dailyWeather?.append(WeatherForecastDay(date: dates[9], lowTemperatureCelsius: 12,
            highTemperatureCelsius: 22, condition: "Clear", symbolName: "sun.max", precipitationChance: 0))
        let complete = WeatherDashboardForecast(reading: early, referenceDate: earlyMorning)
        precondition(complete.weatherDays.map(\.date) == dates)

        // Missing all data should produce an empty state, not ten placeholder rows.
        early.dailyWeather = nil
        early.dailyForecast = []
        let empty = WeatherDashboardForecast(reading: early, referenceDate: earlyMorning)
        precondition(empty.weatherDays.isEmpty && empty.dewPointDays.isEmpty)
        // Invalid numeric ranges are unavailable too; they must not create blank bars.
        early.dailyWeather = [WeatherForecastDay(date: dates[0], lowTemperatureCelsius: .nan,
            highTemperatureCelsius: 20, condition: "Clear", symbolName: "sun.max", precipitationChance: 0)]
        precondition(WeatherDashboardForecast(reading: early, referenceDate: earlyMorning).weatherDays.isEmpty)
        early.dailyWeather?[0].lowTemperatureCelsius = 30
        precondition(WeatherDashboardForecast(reading: early, referenceDate: earlyMorning).weatherDays.isEmpty)
        print("Weather dashboard forecast tests passed")
    }
}
