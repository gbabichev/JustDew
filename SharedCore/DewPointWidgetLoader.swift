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
        let dailyDewPoints = [
            [8.0, 8.5, 9.5, 11.0, 13.0, 15.0, 16.5, 16.0, 14.0, 12.0, 10.5, 9.5],
            [9.0, 10.0, 12.0, 14.5, 17.0, 18.0, 17.0, 15.0],
            [11.0, 12.5, 15.0, 18.0, 20.0, 20.5, 19.0, 16.0],
            [13.0, 14.0, 16.0, 19.0, 21.5, 22.0, 20.0, 17.5],
            [10.0, 11.0, 13.0, 16.0, 18.0, 18.5, 16.0, 13.0],
            [7.0, 8.0, 10.0, 12.0, 14.0, 14.5, 12.0, 9.0]
        ]

        return dailyDewPoints.enumerated().flatMap { dayIndex, dewPoints in
            dewPoints.enumerated().compactMap { hourIndex, dewPointCelsius in
                guard let dayStart = calendar.date(byAdding: .day, value: dayIndex, to: start),
                      let date = calendar.date(byAdding: .hour, value: hourIndex * 3, to: dayStart) else {
                    return nil
                }

                return DewPointForecastPoint(
                    date: date,
                    dewPointCelsius: dewPointCelsius,
                    temperatureCelsius: 19.0 + Double(hourIndex),
                    humidity: 0.48 + Double(hourIndex) * 0.02
                )
            }
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

    // Configurable widgets never change the app's selected location or legacy cache.
    static func loadReading(locationID: String) async throws -> DewPointReading {
        let store = DewPointStore()
        let location: DewPointLocation
        if locationID == "current" {
            let current = try await currentWidgetLocation()
            let names = await LocationSearchService.currentLocationNames(for: current)
            location = DewPointLocation(mode: .current, name: names.name, shortName: names.shortName,
                                        latitude: current.coordinate.latitude, longitude: current.coordinate.longitude,
                                        savedAt: Date())
        } else {
            guard let saved = store.loadLocations().first(where: { $0.id == locationID }) else {
                throw DewPointError.missingConfiguredLocation
            }
            location = saved
        }
        let reading = try await DewPointWeatherClient.reading(for: location)
        store.saveCachedReading(reading)
        return reading
    }

    static func cachedReading(locationID: String) -> DewPointReading? {
        let store = DewPointStore()
        if let location = store.loadLocations().first(where: { $0.id == locationID }) {
            return store.loadReading(for: location)
        }
        if locationID == "current" {
            let current = DewPointLocation(mode: .current, name: "Current Location", latitude: 0,
                                           longitude: 0, savedAt: Date())
            return store.loadReading(for: current)
        }
        return nil
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
