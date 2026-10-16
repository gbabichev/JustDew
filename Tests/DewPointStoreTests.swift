import Foundation

// Run with swiftc and SharedCore/{DewPointModels,DewPointConfiguration,DewPointStore}.swift.
@main
struct DewPointStoreTests {
    static func main() throws {
        let suite = "JustDewStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DewPointStore(defaults: defaults)
        let first = DewPointLocation(mode: .manual, name: "Boston", latitude: 42.36, longitude: -71.06, savedAt: .now)
        let second = DewPointLocation(mode: .manual, name: "Miami", latitude: 25.76, longitude: -80.19, savedAt: .now)
        let now = Date()
        func reading(_ location: DewPointLocation, dew: Double) -> DewPointReading {
            DewPointReading(location: location, dewPointCelsius: dew, temperatureCelsius: 25,
                            humidity: 0.5, condition: "Clear", symbolName: "sun.max", observedAt: now, fetchedAt: now)
        }

        // Old installations retain their existing location and cached weather.
        defaults.set(try JSONEncoder().encode(first), forKey: "dewPoint.location")
        defaults.set(try JSONEncoder().encode(reading(first, dew: 10)), forKey: "dewPoint.reading")
        precondition(store.loadLocations() == [first])
        precondition(store.loadReading(for: first)?.dewPointCelsius == 10)
        precondition(store.loadReading(for: second) == nil)

        store.saveLocations([first, second])
        store.saveReading(reading(first, dew: 11))
        store.saveCachedReading(reading(second, dew: 22))
        precondition(store.loadLocation() == first, "Widget refresh must not change the app selection")
        precondition(store.loadReading()?.location == first, "Widget refresh must not replace legacy widget data")
        precondition(store.loadReading(for: first)?.dewPointCelsius == 11)
        precondition(store.loadReading(for: second)?.dewPointCelsius == 22)
        precondition(store.loadLocations() == [first, second])

        let current = DewPointLocation(mode: .current, name: "Current Location", latitude: 40.7,
                                       longitude: -74, savedAt: now)
        // Normalize existing installations as well as newly saved lists, without sorting cities.
        defaults.set(try JSONEncoder().encode([second, current, first]), forKey: "dewPoint.locations")
        precondition(store.loadLocations() == [current, second, first])
        store.saveLocations([second, first, current])
        let persisted = try JSONDecoder().decode([DewPointLocation].self,
            from: defaults.data(forKey: "dewPoint.locations")!)
        precondition(persisted == [current, second, first])
        precondition(DewPointStore.orderedLocations([second, first]) == [second, first])
        store.saveLocations([first, second])

        // The final supported day must survive cache merging; day eleven must not.
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let lastDay = calendar.date(byAdding: .day, value: 9, to: start)!
        let outside = calendar.date(byAdding: .day, value: 10, to: start)!
        func point(_ date: Date) -> DewPointForecastPoint {
            DewPointForecastPoint(date: date, dewPointCelsius: 15, temperatureCelsius: 25, humidity: 0.5)
        }
        var extended = reading(first, dew: 12)
        extended.dailyForecast = [point(lastDay), point(outside)]
        store.saveReading(extended)
        store.saveReading(reading(first, dew: 13))
        let forecast = store.loadReading(for: first)!.dailyForecastPoints
        precondition(forecast.contains { $0.date == lastDay }, "Keep the tenth forecast day")
        precondition(!forecast.contains { $0.date >= outside }, "Exclude the eleventh day")

        // Calendar days remain correct across a daylight saving transition.
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let springDate = newYork.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 12))!
        let range = DewPointConfiguration.forecastDateRange(for: springDate, calendar: newYork)
        precondition(newYork.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day == 10)
        precondition(range.upperBound.timeIntervalSince(range.lowerBound) == 10 * 86_400 - 3_600)

        var moving = first
        moving.mode = .current
        var moved = moving
        moved.latitude = 30
        precondition(moving.id == moved.id, "Current Location identity must survive movement")
        precondition(first.id != second.id)
        store.saveLocations([])
        precondition(store.loadLocations().isEmpty, "Deleting the last location must not resurrect legacy data")
        print("DewPointStore tests passed")
    }
}
