import Foundation

private actor WeatherStub {
    var requests: [String] = []
    var failingID: String?

    func fetch(_ location: DewPointLocation) async throws -> DewPointReading {
        requests.append(location.id)
        if location.id == failingID { throw URLError(.notConnectedToInternet) }
        return Self.reading(location, temperature: 25)
    }

    func fail(_ id: String?) { failingID = id }
    func reset() { requests = [] }

    static func reading(_ location: DewPointLocation, temperature: Double) -> DewPointReading {
        let now = Date()
        let details = DewPointHourlyWeather(precipitationChance: 0.2, windSpeedMetersPerSecond: 2,
            windDirection: "N", uvIndex: 1, uvCategory: "Low", condition: "Clear", symbolName: "sun.max")
        return DewPointReading(location: location, dewPointCelsius: 10, temperatureCelsius: temperature,
            humidity: 0.5, condition: "Clear", symbolName: "sun.max", observedAt: now, fetchedAt: now,
            dailyForecast: [DewPointForecastPoint(date: now.addingTimeInterval(9 * 86400),
                dewPointCelsius: 10, temperatureCelsius: temperature, humidity: 0.5, weather: details)],
            dailyWeather: [])
    }
}

@main
struct SavedLocationsRefreshTests {
    @MainActor
    static func main() async {
        let suite = "JustDew.RefreshTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DewPointStore(defaults: defaults)
        let cities = (0..<3).map {
            DewPointLocation(mode: .manual, name: "City \($0)", latitude: Double($0), longitude: 1, savedAt: Date())
        }
        store.saveLocations(cities)
        for city in cities { store.saveCachedReading(WeatherStub.reading(city, temperature: 5)) }
        store.saveLocation(cities[0])
        let stub = WeatherStub()
        let model = DewPointViewModel(store: store, fetchWeather: { try await stub.fetch($0) })
        // Even fresh caches refresh on cold launch; overlapping lifecycle callbacks share the task.
        let first = model.refreshSavedLocationsIfNeeded()
        let overlapping = model.refreshSavedLocationsIfNeeded()
        await first.value
        await overlapping.value
        let requests = await stub.requests
        precondition(requests.count == 3 && Set(requests) == Set(cities.map(\.id)))
        precondition(model.configuredLocation?.id == cities[0].id)
        precondition(store.loadLocation()?.id == cities[0].id, "Background refresh must not change persisted selection")
        for city in cities { precondition(model.cachedReading(for: city)?.temperatureCelsius == 25) }

        // Fresh foreground callbacks do not repeat network calls.
        await stub.reset()
        await model.refreshSavedLocationsIfNeeded().value
        let foregroundRequests = await stub.requests
        precondition(foregroundRequests.isEmpty)

        // One failing city retains its cache while the following city still refreshes.
        for city in cities.dropFirst() {
            var stale = WeatherStub.reading(city, temperature: 7)
            stale.fetchedAt = Date().addingTimeInterval(-86400)
            store.saveCachedReading(stale)
        }
        await stub.fail(cities[1].id)
        await model.refreshSavedLocationsIfNeeded().value
        let retried = await stub.requests
        precondition(retried == Array(cities.dropFirst()).map(\.id))
        precondition(model.cachedReading(for: cities[1])?.temperatureCelsius == 7)
        precondition(model.cachedReading(for: cities[2])?.temperatureCelsius == 25)
        precondition(model.configuredLocation?.id == cities[0].id)
        print("Saved location refresh tests passed")
    }
}
