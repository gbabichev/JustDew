import CoreLocation
import Foundation

enum DewPointWidgetLoader {
    static var sampleReading: DewPointReading {
        let location = DewPointLocation(
            mode: .manual,
            name: "Cupertino, CA",
            shortName: "Cupertino, CA",
            latitude: 37.3349,
            longitude: -122.0090,
            savedAt: Date()
        )

        return DewPointReading(
            location: location,
            dewPointCelsius: 9.4,
            temperatureCelsius: 20.0,
            humidity: 0.52,
            condition: "Clear",
            symbolName: "sun.max.fill",
            observedAt: Date(),
            fetchedAt: Date()
        )
    }

    static func loadReading() async throws -> DewPointReading {
        let store = DewPointStore()
        guard var location = store.loadLocation() else {
            throw DewPointError.missingConfiguredLocation
        }

        if location.mode == .current, let updatedLocation = try? await currentWidgetLocation() {
            let names = await LocationSearchService.currentLocationNames(for: updatedLocation)
            location = DewPointLocation(
                mode: .current,
                name: names.name,
                shortName: names.shortName,
                latitude: updatedLocation.coordinate.latitude,
                longitude: updatedLocation.coordinate.longitude,
                savedAt: Date()
            )
            store.saveLocation(location)
        }

        let reading = try await DewPointWeatherClient.reading(for: location)
        store.saveReading(reading)
        return reading
    }

    @MainActor
    private static func currentWidgetLocation() async throws -> CLLocation {
        let provider = OneShotLocationProvider()
        return try await provider.requestLocation(
            requestPermission: false,
            requireWidgetAuthorization: true
        )
    }
}
