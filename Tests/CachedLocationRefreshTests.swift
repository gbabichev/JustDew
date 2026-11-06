import CoreLocation
import Foundation
import MapKit

// Only needed to compile the view model without the autocomplete UI.
struct LocationSuggestion { let completion: MKLocalSearchCompletion }

private final class SilentLocationManager: CLLocationManager {
    override var authorizationStatus: CLAuthorizationStatus { .authorizedAlways }
    override func requestLocation() {}
    override func stopUpdatingLocation() {}
}

private actor WeatherStub {
    var requests: [DewPointLocation] = []
    var shouldFail = false

    func fetch(_ location: DewPointLocation) throws -> DewPointReading {
        requests.append(location)
        if shouldFail { throw URLError(.notConnectedToInternet) }
        return Self.reading(location, temperature: 20)
    }

    func fail() { shouldFail = true }

    static func reading(_ location: DewPointLocation, temperature: Double) -> DewPointReading {
        DewPointReading(location: location, dewPointCelsius: 10, temperatureCelsius: temperature,
                        humidity: 0.5, condition: "Clear", symbolName: "sun.max",
                        observedAt: .now, fetchedAt: .now)
    }
}

@main
struct CachedLocationRefreshTests {
    @MainActor
    static func main() async {
        let suite = "JustDew.CachedLocationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DewPointStore(defaults: defaults)
        let location = DewPointLocation(mode: .current, name: "Waxhaw, NC", latitude: 34.9246,
                                       longitude: -80.7434, savedAt: .now, timeZoneIdentifier: "America/New_York")
        store.saveLocations([location])
        store.saveLocation(location)
        let cached = WeatherStub.reading(location, temperature: 5)
        store.saveCachedReading(cached)
        let stub = WeatherStub()
        let provider = OneShotLocationProvider(manager: SilentLocationManager(), timeout: .milliseconds(20))
        let model = DewPointViewModel(store: store, locationProvider: provider,
                                     fetchWeather: { try await stub.fetch($0) })

        await model.refreshNow()
        let requests = await stub.requests
        precondition(requests.count == 1 && requests[0] == location,
                     "GPS timeout must fetch weather using the saved coordinates")
        precondition(model.reading?.temperatureCelsius == 20 && !model.isLoading)
        precondition(model.errorMessage == DewPointError.usingLastKnownLocation.localizedDescription,
                     "Fresh weather must not clear the location warning")
        precondition(store.loadReading(for: location)?.temperatureCelsius == 20,
                     "Fallback weather must update the shared cache")

        await stub.fail()
        let previousDate = model.reading?.fetchedAt
        await model.refreshNow()
        precondition(model.reading?.fetchedAt == previousDate && !model.isLoading,
                     "Weather failure must keep the previous reading and stop loading")
        precondition(model.errorMessage == DewPointError.networkUnavailable.localizedDescription)
        print("Cached-location weather refresh and failure checks passed")
    }
}
