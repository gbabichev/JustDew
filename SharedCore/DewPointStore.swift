import Foundation

struct DewPointStore {
    private enum Key {
        static let location = "dewPoint.location"
        static let reading = "dewPoint.reading"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        defaults = UserDefaults(suiteName: DewPointConfiguration.appGroupIdentifier) ?? .standard
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
        let mergedReading = mergedReading(existing: loadReading(), incoming: reading)
        encode(mergedReading, forKey: Key.reading)
        encode(mergedReading.location, forKey: Key.location)
    }

    func clearLocationAndReading() {
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
              isSameForecastDay(existing.observedAt, incoming.observedAt),
              isSameLocation(existing.location, incoming.location) else {
            return incoming
        }

        var mergedReading = incoming
        let forecastPoints = (existing.dailyForecastPoints + incoming.dailyForecastPoints)
            .filter { isSameForecastDay($0.date, incoming.observedAt) }
            .uniquedByHour()
            .sorted { $0.date < $1.date }

        mergedReading.dailyForecast = forecastPoints
        return mergedReading
    }

    private func isSameForecastDay(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }

    private func isSameLocation(_ lhs: DewPointLocation, _ rhs: DewPointLocation) -> Bool {
        abs(lhs.latitude - rhs.latitude) < 0.05 && abs(lhs.longitude - rhs.longitude) < 0.05
    }
}

private extension Array where Element == DewPointForecastPoint {
    func uniquedByHour() -> [DewPointForecastPoint] {
        let calendar = Calendar.current

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
        let components = dateComponents([.year, .month, .day, .hour], from: date)
        return self.date(from: components) ?? date
    }
}
