import Foundation

enum DewPointComfortLimit: Int, CaseIterable, Identifiable {
    case standard = 55
    case moderate = 60
    case relaxed = 65

    var id: Int { rawValue }
    var celsius: Double { (Double(rawValue) - 32) * 5 / 9 }
    var temperature: Measurement<UnitTemperature> { Measurement(value: celsius, unit: .celsius) }
}

/// Moisture comfort only: this does not classify temperature, wind, or rain.
struct DewPointComfortAnalysis {
    enum Condition {
        case dry, humid, muggy, unavailable
    }

    let referenceDate: Date
    let dayEnd: Date
    let condition: Condition
    let isRecent: Bool
    let windows: [DateInterval]
    let hasHourlyForecast: Bool
    let hasCompleteCoverage: Bool

    init(reading: DewPointReading, limit: DewPointComfortLimit = .standard, referenceDate: Date = .now) {
        self.referenceDate = referenceDate
        let calendar = reading.forecastCalendar
        let dayStart = calendar.startOfDay(for: referenceDate)
        dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let age = referenceDate.timeIntervalSince(reading.observedAt)
        isRecent = age >= -300 && age <= 5_400 && calendar.isDate(reading.observedAt, inSameDayAs: referenceDate)
        if !reading.dewPointCelsius.isFinite {
            condition = .unavailable
        } else if reading.dewPointCelsius <= DewPointComfortLimit.standard.celsius {
            condition = .dry
        } else if reading.dewPointCelsius < DewPointComfortLimit.relaxed.celsius {
            condition = .humid
        } else {
            condition = .muggy
        }

        // Each hourly point describes only its own hour. Never bridge a data gap
        // or extend today's last point through the rest of the evening.
        var pointsByDate: [Date: DewPointForecastPoint] = [:]
        for point in reading.dailyForecastPoints { pointsByDate[point.date] = point }
        var coverage: [DateInterval] = []
        var comfortable: [DateInterval] = []
        let points = pointsByDate.values.sorted(by: { $0.date < $1.date })
        for (index, point) in points.enumerated() {
            guard point.dewPointCelsius.isFinite, point.date >= dayStart, point.date < dayEnd else { continue }
            let start = max(referenceDate, point.date)
            let nextDate = index + 1 < points.count ? points[index + 1].date : dayEnd
            let end = min(dayEnd, nextDate, point.date.addingTimeInterval(3_600))
            guard end > start else { continue }
            let interval = DateInterval(start: start, end: end)
            coverage.append(interval)
            if point.dewPointCelsius <= limit.celsius { comfortable.append(interval) }
        }
        windows = Self.merged(comfortable)
        hasHourlyForecast = !coverage.isEmpty
        let mergedCoverage = Self.merged(coverage)
        hasCompleteCoverage = mergedCoverage.count == 1
            && mergedCoverage[0].start == referenceDate && mergedCoverage[0].end == dayEnd
    }

    private static func merged(_ intervals: [DateInterval]) -> [DateInterval] {
        var result: [DateInterval] = []
        for interval in intervals {
            if let last = result.last, interval.start <= last.end {
                result[result.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                result.append(interval)
            }
        }
        return result
    }
}
