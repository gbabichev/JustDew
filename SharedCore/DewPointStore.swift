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
        encode(reading, forKey: Key.reading)
        encode(reading.location, forKey: Key.location)
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
