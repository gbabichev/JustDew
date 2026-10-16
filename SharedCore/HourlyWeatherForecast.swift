import Foundation

struct DewPointHourlyWeather: Codable, Equatable, Sendable {
    var precipitationChance: Double
    var windSpeedMetersPerSecond: Double
    var windGustMetersPerSecond: Double?
    var windDirection: String
    var uvIndex: Int
    var uvCategory: String
    var condition: String
    var symbolName: String
}

struct HourlyWeatherForecast {
    struct Hour: Identifiable {
        let start: Date
        let end: Date
        let point: DewPointForecastPoint
        var id: Date { start }
    }

    struct Day: Identifiable {
        let date: Date
        let hours: [Hour]
        var id: Date { date }
    }

    let days: [Day]
    let hasDetails: Bool

    init(reading: DewPointReading, referenceDate: Date = .now) {
        let calendar = reading.forecastCalendar
        let end = referenceDate.addingTimeInterval(24 * 3_600)
        var hoursByStart: [Date: Hour] = [:]
        for point in reading.dailyForecastPoints {
            guard let slot = calendar.dateInterval(of: .hour, for: point.date),
                  slot.end > referenceDate, slot.start < end else { continue }
            hoursByStart[slot.start] = Hour(start: slot.start, end: slot.end, point: point)
        }
        let hours = hoursByStart.values.sorted { $0.start < $1.start }
        hasDetails = hours.contains { $0.point.weather != nil }
        let grouped = Dictionary(grouping: hours) { calendar.startOfDay(for: $0.start) }
        days = grouped.keys.sorted().map { Day(date: $0, hours: grouped[$0]!) }
    }
}
