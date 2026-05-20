import CoreLocation
import Foundation

enum DewPointWidgetLoader {
    static var sampleReading: DewPointReading {
        let location = DewPointLocation(
            mode: .manual,
            name: "Charlotte, NC",
            shortName: "Charlotte, NC",
            latitude: 34.9246,
            longitude: 80.7434,
            savedAt: Date()
        )

        // cupertino
//        let location = DewPointLocation(
//            mode: .manual,
//            name: "Cupertino, CA",
//            shortName: "Cupertino, CA",
//            latitude: 37.3349,
//            longitude: -122.0090,
//            savedAt: Date()
//        )

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
            let resolvedNames = currentLocationNames(names, fallingBackTo: location)
            location = DewPointLocation(
                mode: .current,
                name: resolvedNames.name,
                shortName: resolvedNames.shortName,
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

    private static func currentLocationNames(
        _ names: (name: String, shortName: String?),
        fallingBackTo existingLocation: DewPointLocation
    ) -> (name: String, shortName: String?) {
        let resolvedLocation = DewPointLocation(
            mode: .current,
            name: names.name,
            shortName: names.shortName,
            latitude: existingLocation.latitude,
            longitude: existingLocation.longitude,
            savedAt: existingLocation.savedAt
        )

        guard !resolvedLocation.hasSpecificDisplayName, existingLocation.hasSpecificDisplayName else {
            return names
        }

        return (existingLocation.name, existingLocation.shortName)
    }
}
