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
            fetchedAt: Date(),
            dailyForecast: sampleDailyForecast()
        )
    }

    private static func sampleDailyForecast() -> [DewPointForecastPoint] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let dewPoints = [8.0, 8.5, 9.5, 11.0, 13.0, 15.0, 16.5, 16.0, 14.0, 12.0, 10.5, 9.5]

        return dewPoints.enumerated().compactMap { index, dewPointCelsius in
            guard let date = calendar.date(byAdding: .hour, value: index * 2, to: start) else { return nil }

            return DewPointForecastPoint(
                date: date,
                dewPointCelsius: dewPointCelsius,
                temperatureCelsius: 19.0 + Double(index),
                humidity: 0.48 + Double(index) * 0.02
            )
        }
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
