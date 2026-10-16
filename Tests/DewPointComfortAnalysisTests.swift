import Foundation

@main
struct DewPointComfortAnalysisTests {
    static func main() {
        let iso = ISO8601DateFormatter()
        let now = iso.date(from: "2026-10-16T00:30:00Z")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let location = DewPointLocation(mode: .manual, name: "Tokyo", latitude: 35, longitude: 139,
            savedAt: now, timeZoneIdentifier: calendar.timeZone.identifier)
        var reading = DewPointReading(location: location, dewPointCelsius: 12, temperatureCelsius: 20,
            humidity: 0.5, condition: "Clear", symbolName: "sun.max", observedAt: now, fetchedAt: now)
        func point(_ hour: Int, _ dew: Double = 10) -> DewPointForecastPoint {
            DewPointForecastPoint(date: start.addingTimeInterval(Double(hour) * 3_600),
                dewPointCelsius: dew, temperatureCelsius: 20, humidity: 0.5)
        }
        reading.dailyForecast = (0..<24).map { point($0) }
        var analysis = DewPointComfortAnalysis(reading: reading, referenceDate: now)
        precondition(analysis.condition == .dry && analysis.isRecent)
        precondition(analysis.windows == [DateInterval(start: now, end: end)])
        precondition(analysis.hasCompleteCoverage, "Use the location's local day, not UTC")

        // Separate comfortable stretches and exclude already elapsed hours.
        reading.dailyForecast = (0..<24).map { point($0, (10..<18).contains($0) ? 20 : 10) }
        analysis = DewPointComfortAnalysis(reading: reading, referenceDate: now)
        precondition(analysis.windows.count == 2)
        precondition(analysis.windows[0] == DateInterval(start: now, end: point(10).date))
        precondition(analysis.windows[1] == DateInterval(start: point(18).date, end: end))

        // Gaps, invalid values, and a truncated forecast must not become all-day claims.
        reading.dailyForecast = [point(9), point(11), point(12, .nan), point(13)]
        analysis = DewPointComfortAnalysis(reading: reading, referenceDate: now)
        precondition(analysis.windows.count == 3 && !analysis.hasCompleteCoverage)
        precondition(analysis.windows[0].end == point(10).date)
        precondition(analysis.windows[1].end == point(12).date)
        precondition(analysis.windows[2].end == point(14).date)
        reading.dailyForecast = [point(9, 20)]
        analysis = DewPointComfortAnalysis(reading: reading, referenceDate: now)
        precondition(analysis.windows.isEmpty && analysis.hasHourlyForecast && !analysis.hasCompleteCoverage)
        reading.dailyForecast = nil
        precondition(!DewPointComfortAnalysis(reading: reading, referenceDate: now).hasHourlyForecast)

        // User-selected limit, exact boundary, and transitions from a current snapshot.
        reading.dailyForecast = [point(10, 15)]
        precondition(DewPointComfortAnalysis(reading: reading, referenceDate: now).windows.isEmpty)
        precondition(DewPointComfortAnalysis(reading: reading, limit: .moderate, referenceDate: now).windows.count == 1)
        reading.dailyForecast = [point(10, DewPointComfortLimit.standard.celsius)]
        precondition(DewPointComfortAnalysis(reading: reading, referenceDate: now).windows.count == 1)
        reading.dailyForecast = [DewPointForecastPoint(date: now, dewPointCelsius: 10, temperatureCelsius: 20, humidity: 0.5), point(10, 20)]
        precondition(DewPointComfortAnalysis(reading: reading, referenceDate: now).windows[0].end == point(10).date)

        reading.dewPointCelsius = 16
        precondition(DewPointComfortAnalysis(reading: reading, referenceDate: now).condition == .humid)
        reading.dewPointCelsius = 20
        precondition(DewPointComfortAnalysis(reading: reading, referenceDate: now).condition == .muggy)
        reading.dewPointCelsius = .nan
        precondition(DewPointComfortAnalysis(reading: reading, referenceDate: now).condition == .unavailable)
        reading.observedAt = now.addingTimeInterval(-7_200)
        precondition(!DewPointComfortAnalysis(reading: reading, referenceDate: now).isRecent)

        // DST days contain 23 or 25 real hourly slots; both 1 AM hours stay distinct.
        for (month, day, hours) in [(3, 8, 23), (11, 1, 25)] {
            calendar.timeZone = TimeZone(identifier: "America/New_York")!
            let dstStart = calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
            let dstEnd = calendar.date(byAdding: .day, value: 1, to: dstStart)!
            reading.location.timeZoneIdentifier = calendar.timeZone.identifier
            reading.dailyForecast = (0..<hours).map { hour in
                DewPointForecastPoint(date: dstStart.addingTimeInterval(Double(hour) * 3_600),
                    dewPointCelsius: 10, temperatureCelsius: 20, humidity: 0.5)
            }
            let dst = DewPointComfortAnalysis(reading: reading, referenceDate: dstStart)
            precondition(dst.hasCompleteCoverage && dst.windows.count == 1)
            precondition(dst.windows[0] == DateInterval(start: dstStart, end: dstEnd))
            precondition(dst.windows[0].duration == Double(hours) * 3_600)
        }
        print("Comfort analysis tests passed")
    }
}
