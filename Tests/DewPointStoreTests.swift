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
