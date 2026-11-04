import Foundation

@main
struct DewPointComfortAnalysisTests {
    static func main() {
        let iso = ISO8601DateFormatter()
        let now = iso.date(from: "2026-10-16T00:30:00Z")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let location = DewPointLocation(mode: .manual, name: "Tokyo", latitude: 35, longitude: 139,
            savedAt: now, timeZoneIdentifier: calendar.timeZone.identifier)
        var reading = DewPointReading(location: location, dewPointCelsius: 12, temperatureCelsius: 20,
            humidity: 0.5, condition: "Clear", symbolName: "sun.max", observedAt: now, fetchedAt: now)
        let analysis = DewPointComfortAnalysis(reading: reading, referenceDate: now)
        precondition(analysis.condition == .dry && analysis.isRecent)

        reading.dewPointCelsius = 16
        precondition(DewPointComfortAnalysis(reading: reading, referenceDate: now).condition == .humid)
        reading.dewPointCelsius = 20
        precondition(DewPointComfortAnalysis(reading: reading, referenceDate: now).condition == .muggy)
        reading.dewPointCelsius = .nan
        precondition(DewPointComfortAnalysis(reading: reading, referenceDate: now).condition == .unavailable)
        reading.observedAt = now.addingTimeInterval(-7_200)
        precondition(!DewPointComfortAnalysis(reading: reading, referenceDate: now).isRecent)

        print("Comfort analysis tests passed")
    }
}
