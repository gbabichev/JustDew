import Combine
import Foundation

private actor SuspendedWeather {
    private var pending: [String: CheckedContinuation<DewPointReading, Error>] = [:]
    private var waiters: [String: [CheckedContinuation<Void, Never>]] = [:]
    private(set) var requests: [String] = []

    func fetch(_ location: DewPointLocation) async throws -> DewPointReading {
        requests.append(location.id)
        return try await withCheckedThrowingContinuation { continuation in
            precondition(pending[location.id] == nil, "Duplicate request for the same location")
            pending[location.id] = continuation
            for waiter in waiters.removeValue(forKey: location.id) ?? [] { waiter.resume() }
        }
    }

    func waitForRequest(_ location: DewPointLocation) async {
        if pending[location.id] != nil { return }
        await withCheckedContinuation { waiters[location.id, default: []].append($0) }
    }

    func finish(_ location: DewPointLocation, temperature: Double) {
        pending.removeValue(forKey: location.id)!.resume(returning: Self.reading(location, temperature: temperature))
    }

    func fail(_ location: DewPointLocation) {
        pending.removeValue(forKey: location.id)!.resume(throwing: URLError(.notConnectedToInternet))
    }

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
struct ResponsiveRefreshTests {
    @MainActor
    static func main() async throws {
        let suite = "JustDew.ResponsiveRefresh.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DewPointStore(defaults: defaults)
        let cities = (0..<3).map {
            DewPointLocation(mode: .manual, name: "City \($0)", latitude: Double($0), longitude: 1, savedAt: Date())
        }
        store.saveLocations(cities)
        store.saveLocation(cities[0])
        for city in cities {
            var cached = SuspendedWeather.reading(city, temperature: 5)
            cached.fetchedAt = Date().addingTimeInterval(-86400)
            store.saveCachedReading(cached)
        }
        let stub = SuspendedWeather()
        let model = DewPointViewModel(store: store, fetchWeather: { try await stub.fetch($0) })
        var showedBlockingProgress = false
        let observation = model.$isLoading.sink { if $0 { showedBlockingProgress = true } }
        let launch = model.refreshSavedLocationsIfNeeded()
        await stub.waitForRequest(cities[0])
        precondition(!model.isLoading && !model.isLoadingReading(for: cities[0]))
        precondition(model.reading?.temperatureCelsius == 5, "Cached data must remain visible")

        // Navigate while the initial city's network response is deliberately suspended.
        model.selectLocation(cities[1])
        precondition(model.configuredLocation?.id == cities[1].id)
        precondition(model.reading?.location.id == cities[1].id)
        await stub.waitForRequest(cities[1])
        // A repeated stale-page load must join the pending request rather than start another.
        model.loadInitialReading()
        await stub.finish(cities[1], temperature: 26)
        try await eventually { model.reading?.temperatureCelsius == 26 }
        model.removeLocation(id: cities[2].id)
        await stub.finish(cities[0], temperature: 25)
        await launch.value
        precondition(model.configuredLocation?.id == cities[1].id)
        precondition(store.loadLocation()?.id == cities[1].id)
        precondition(model.reading?.temperatureCelsius == 26, "Late response must not replace the selected city")
        precondition(model.cachedReading(for: cities[0])?.temperatureCelsius == 25,
                     "Other cities should still receive their refreshed cache")
        let requests = await stub.requests
        precondition(requests == [cities[0].id, cities[1].id])

        // Remove an in-flight city and ensure its completion cannot add it back.
        var stale = SuspendedWeather.reading(cities[0], temperature: 5)
        stale.fetchedAt = Date().addingTimeInterval(-86400)
        store.saveCachedReading(stale)
        let resume = model.refreshSavedLocationsIfNeeded()
        await stub.waitForRequest(cities[0])
        model.removeLocation(id: cities[0].id)
        await stub.finish(cities[0], temperature: 30)
        await resume.value
        precondition(model.savedLocations.map(\.id) == [cities[1].id])
        precondition(store.loadLocations().map(\.id) == [cities[1].id])
        precondition(model.reading?.temperatureCelsius == 26)
        precondition(!showedBlockingProgress, "Automatic refresh must never enter the UI-blocking loading state")
        observation.cancel()

        // Explicit refresh still has progress feedback.
        let manual = Task { await model.refreshNow() }
        await stub.waitForRequest(cities[1])
        precondition(model.isLoading)
        await stub.finish(cities[1], temperature: 27)
        await manual.value
        precondition(!model.isLoading && model.reading?.temperatureCelsius == 27)

        // Without a cache, show a page-local loading state, never a global interaction lock.
        defaults.removePersistentDomain(forName: suite)
        store.saveLocations([cities[0]])
        store.saveLocation(cities[0])
        let empty = DewPointViewModel(store: store, fetchWeather: { try await stub.fetch($0) })
        let firstLoad = empty.refreshSavedLocationsIfNeeded()
        await stub.waitForRequest(cities[0])
        precondition(empty.reading == nil && !empty.isLoading)
        precondition(empty.isLoadingReading(for: cities[0]))
        await stub.fail(cities[0])
        await firstLoad.value
        precondition(!empty.isLoadingReading(for: cities[0]))
        precondition(empty.errorMessage != nil)
        print("Responsive refresh tests passed")
    }

    @MainActor
    private static func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        preconditionFailure("Refresh result did not reach the UI")
    }
}
