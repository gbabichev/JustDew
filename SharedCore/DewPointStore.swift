import Foundation

struct DewPointStore {
    private enum Key {
        static let location = "dewPoint.location"
        static let reading = "dewPoint.reading"
        static let locations = "dewPoint.locations"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = UserDefaults(suiteName: DewPointConfiguration.appGroupIdentifier) ?? .standard) {
        self.defaults = defaults
    }

    func loadLocations() -> [DewPointLocation] {
        if let locations = decode([DewPointLocation].self, forKey: Key.locations) {
            return locations
        }
        // Preserve the location configured before multiple locations were supported.
        return loadLocation().map { [$0] } ?? []
    }

    func saveLocations(_ locations: [DewPointLocation]) {
        encode(locations, forKey: Key.locations)
    }

    func loadReading(for location: DewPointLocation) -> DewPointReading? {
        if let reading = decode(DewPointReading.self, forKey: "dewPoint.reading.\(location.id)") {
            return reading
        }
        guard let reading = loadReading(), reading.location.id == location.id else { return nil }
        return reading
    }

    func saveCachedReading(_ reading: DewPointReading) {
        let merged = mergedReading(existing: loadReading(for: reading.location), incoming: reading)
        encode(merged, forKey: "dewPoint.reading.\(reading.location.id)")
    }

    func freshReading(for location: DewPointLocation, now: Date = Date()) -> DewPointReading? {
        guard let reading = loadReading(for: location),
              isSameLocation(reading.location, location),
              reading.dailyWeather != nil else { return nil }
        let age = now.timeIntervalSince(reading.fetchedAt)
        guard age >= 0, age < DewPointConfiguration.refreshInterval else { return nil }
        return reading
    }

    func loadLocation() -> DewPointLocation? {
        decode(DewPointLocation.self, forKey: Key.location)
    }

    func saveLocation(_ location: DewPointLocation) {
        encode(location, forKey: Key.location)
    }

    func loadReading() -> DewPointReading? {
        decode(DewPointReading.self, forKey: Key.reading)
    }

    func saveReading(_ reading: DewPointReading) {
        saveCachedReading(reading)
        let mergedReading = mergedReading(existing: loadReading(for: reading.location), incoming: reading)
        encode(mergedReading, forKey: Key.reading)
        encode(mergedReading.location, forKey: Key.location)
    }

    func clearLocationAndReading() {
        for location in loadLocations() {
            defaults.removeObject(forKey: "dewPoint.reading.\(location.id)")
        }
        defaults.removeObject(forKey: Key.locations)
        defaults.removeObject(forKey: Key.location)
        defaults.removeObject(forKey: Key.reading)
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func mergedReading(existing: DewPointReading?, incoming: DewPointReading) -> DewPointReading {
        guard let existing,
              isSameLocation(existing.location, incoming.location) else {
            return incoming
        }

        var mergedReading = incoming
        mergedReading.location.timeZoneIdentifier = incoming.location.timeZoneIdentifier ?? existing.location.timeZoneIdentifier
        let forecastInterval = DewPointConfiguration.forecastDateRange(for: incoming.observedAt, calendar: mergedReading.forecastCalendar)
        let forecastPoints = (existing.dailyForecastPoints + incoming.dailyForecastPoints)
            .filter { forecastInterval.contains($0.date) }
            .uniquedByHour(calendar: mergedReading.forecastCalendar)
            .sorted { $0.date < $1.date }

        mergedReading.dailyForecast = forecastPoints
        return mergedReading
    }

    private func isSameLocation(_ lhs: DewPointLocation, _ rhs: DewPointLocation) -> Bool {
        abs(lhs.latitude - rhs.latitude) < 0.05 && abs(lhs.longitude - rhs.longitude) < 0.05
    }


}

private extension Array where Element == DewPointForecastPoint {
    func uniquedByHour(calendar: Calendar) -> [DewPointForecastPoint] {

        return reduce(into: [Date: DewPointForecastPoint]()) { partialResult, point in
            let key = calendar.startOfHour(for: point.date)
            partialResult[key] = point
        }
        .values
        .sorted { $0.date < $1.date }
    }
}

private extension Calendar {
    func startOfHour(for date: Date) -> Date {
        dateInterval(of: .hour, for: date)?.start ?? date
    }
}
