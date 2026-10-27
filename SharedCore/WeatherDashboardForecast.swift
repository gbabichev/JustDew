import Foundation

struct WeatherDashboardDay: Identifiable {
    let date: Date
    let weather: WeatherForecastDay?
    let lowDewPointCelsius: Double?
    let highDewPointCelsius: Double?
    let hasPartialDewPoint: Bool

    var id: Date { date }

    var hasWeatherForecast: Bool {
        guard let weather else { return false }
        return weather.lowTemperatureCelsius.isFinite && weather.highTemperatureCelsius.isFinite
            && weather.lowTemperatureCelsius <= weather.highTemperatureCelsius
    }

    var hasDewPointForecast: Bool {
        guard let low = lowDewPointCelsius, let high = highDewPointCelsius else { return false }
        return low.isFinite && high.isFinite && low <= high
    }
}

/// Keep a shared ten-day calendar, and expose only available rows for each forecast.
struct WeatherDashboardForecast {
    let days: [WeatherDashboardDay]
    let weatherDays: [WeatherDashboardDay]
    let dewPointDays: [WeatherDashboardDay]
    let temperatureScale: WeatherRangeScale
    let dewPointScale: WeatherRangeScale

    init(reading: DewPointReading, referenceDate: Date = Date()) {
        let calendar = reading.forecastCalendar
        let start = calendar.startOfDay(for: referenceDate)
        let hourly = reading.dailyForecastPoints.filter { $0.dewPointCelsius.isFinite }
        let days = (0..<DewPointConfiguration.forecastDayCount).compactMap { offset -> WeatherDashboardDay? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start),
                  let end = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
            let points = hourly.filter { $0.date >= date && $0.date < end }.sorted { $0.date < $1.date }
            let weather = reading.dailyWeather?.first { calendar.isDate($0.date, inSameDayAs: date) }
            let partial: Bool
            if let first = points.first, let last = points.last {
                // Full hourly coverage includes the first and last hour, also on DST days.
                let expectedHours = calendar.dateComponents([.hour], from: date, to: end).hour ?? 24
                let sampledHours = Set(points.compactMap { calendar.dateInterval(of: .hour, for: $0.date)?.start }).count
                partial = first.date.timeIntervalSince(date) > 60
                    || end.timeIntervalSince(last.date) > 3_600 || sampledHours < expectedHours
            } else {
                partial = false
            }
            return WeatherDashboardDay(
                date: date, weather: weather,
                lowDewPointCelsius: points.map(\.dewPointCelsius).min(),
                highDewPointCelsius: points.map(\.dewPointCelsius).max(),
                hasPartialDewPoint: partial
            )
        }
        self.days = days
        weatherDays = days.filter(\.hasWeatherForecast)
        dewPointDays = days.filter(\.hasDewPointForecast)
        temperatureScale = WeatherRangeScale(values: weatherDays.flatMap {
            [$0.weather?.lowTemperatureCelsius, $0.weather?.highTemperatureCelsius].compactMap { $0 }
        })
        dewPointScale = WeatherRangeScale(values: dewPointDays.flatMap {
            [$0.lowDewPointCelsius, $0.highDewPointCelsius].compactMap { $0 }
        })
    }
}

struct WeatherRangeScale {
    let lowerBound: Double
    let upperBound: Double

    init(values: [Double]) {
        let finiteValues = values.filter(\.isFinite)
        let low = finiteValues.min() ?? 0
        let high = finiteValues.max() ?? low
        lowerBound = high - low < 1 ? low - 0.5 : low
        upperBound = high - low < 1 ? high + 0.5 : high
    }

    func fraction(for value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max((value - lowerBound) / (upperBound - lowerBound), 0), 1)
    }
}
