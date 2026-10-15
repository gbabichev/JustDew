import Foundation

@main
struct DewPointWidgetCacheTests {
    static func main() throws {
        let suite = "JustDewWidgetCacheTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DewPointStore(defaults: defaults)
        let city = DewPointLocation(mode: .manual, name: "Boston", latitude: 42.36, longitude: -71.06, savedAt: .now)
        let current = DewPointLocation(mode: .current, name: "Miami", latitude: 25.76, longitude: -80.19, savedAt: .now)
        func reading(_ location: DewPointLocation, dew: Double) -> DewPointReading {
            DewPointReading(location: location, dewPointCelsius: dew, temperatureCelsius: 25,
                            humidity: 0.5, condition: "Clear", symbolName: "sun.max",
                            observedAt: .now, fetchedAt: .now)
        }

        // Upgrading from a primary widget that used the last selected manual city
        // must never mislabel that manual cache as Current Location.
        defaults.set(try JSONEncoder().encode(city), forKey: "dewPoint.location")
        defaults.set(try JSONEncoder().encode(reading(city, dew: 10)), forKey: "dewPoint.reading")
        precondition(DewPointWidgetLoader.cachedReading(locationID: "current", store: store) == nil)
        store.saveLocations([city])
        store.saveCachedReading(reading(current, dew: 22))
        precondition(DewPointWidgetLoader.cachedReading(locationID: "current", store: store)?.dewPointCelsius == 22)
        precondition(DewPointWidgetLoader.cachedReading(locationID: city.id, store: store)?.dewPointCelsius == 10)
        precondition(store.loadLocation() == city, "Widget caches must not change the app selection")

        // Even a newer manual reading cannot replace the primary widget's cache.
        store.saveReading(reading(city, dew: 11))
        precondition(DewPointWidgetLoader.cachedReading(locationID: "current", store: store)?.location == current)
        precondition(DewPointWidgetLoader.cachedReading(locationID: city.id, store: store)?.dewPointCelsius == 11)
        store.saveLocations([])
        precondition(DewPointWidgetLoader.cachedReading(locationID: city.id, store: store) == nil)
        precondition(DewPointWidgetLoader.cachedReading(locationID: "current", store: store)?.location == current)
        print("DewPointWidgetCache tests passed")
    }
}
