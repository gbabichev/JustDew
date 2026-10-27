import Foundation

// Compile with SharedCore/*.swift; these checks do not render or launch widgets.
@main
struct WidgetMetricTests {
    @MainActor
    static func main() throws {
        var reading = DewPointWidgetLoader.sampleReading
        reading.dewPointCelsius = 10
        reading.temperatureCelsius = 25
        reading.dailyWeather = [WeatherForecastDay(date: reading.forecastCalendar.startOfDay(for: reading.observedAt),
            lowTemperatureCelsius: 15, highTemperatureCelsius: 35,
            condition: "Clear", symbolName: "sun.max", precipitationChance: 0)]
        precondition(reading.observedDayWeather?.lowTemperatureCelsius == 15)
        precondition(reading.observedDayWeather?.highTemperatureCelsius == 35)
        var otherDay = reading
        otherDay.dailyWeather?[0].date = reading.forecastCalendar.date(byAdding: .day, value: 1, to: reading.observedAt)!
        precondition(otherDay.observedDayWeather == nil, "Do not use tomorrow's range for the current widget")
        var unavailableRange = reading
        unavailableRange.dailyWeather = nil
        precondition(unavailableRange.observedDayWeather == nil)
        unavailableRange.dailyWeather = reading.dailyWeather
        unavailableRange.dailyWeather?[0].lowTemperatureCelsius = .nan
        precondition(unavailableRange.observedDayWeather == nil, "Do not display invalid range labels")
        unavailableRange.dailyWeather?[0].lowTemperatureCelsius = 40
        precondition(unavailableRange.observedDayWeather == nil)
        let point = DewPointForecastPoint(date: reading.observedAt, dewPointCelsius: 12,
                                          temperatureCelsius: 29, humidity: 0.5)
        precondition(DayTimelineMetric.dewPoint.currentValue(in: reading).value == 10)
        precondition(DayTimelineMetric.temperature.currentValue(in: reading).value == 25)
        precondition(DayTimelineMetric.dewPoint.forecastValue(in: point).value == 12)
        precondition(DayTimelineMetric.temperature.forecastValue(in: point).value == 29)
        precondition(DayTimelineMetric.dewPoint.widgetProgress(for: reading) == DewPointComfortScale.progress(for: 10))
        precondition(DayTimelineMetric.temperature.widgetProgress(for: reading) == 0.5)

        // Current temperature can lie outside a forecast's low/high range: gauges must stay valid.
        reading.temperatureCelsius = -30
        precondition(DayTimelineMetric.temperature.widgetProgress(for: reading) == 0)
        reading.temperatureCelsius = 60
        precondition(DayTimelineMetric.temperature.widgetProgress(for: reading) == 1)
        reading.dailyWeather?[0].lowTemperatureCelsius = 60
        reading.dailyWeather?[0].highTemperatureCelsius = 60
        precondition(DayTimelineMetric.temperature.widgetProgress(for: reading).isFinite)
        reading.dailyWeather = nil
        precondition((0...1).contains(DayTimelineMetric.temperature.widgetProgress(for: reading)),
                     "An older cache without daily summaries must still support a weather complication")

        // Dew point bounds use only finite samples from the observation's local day.
        var dewDay = reading
        dewDay.location.timeZoneIdentifier = "America/New_York"
        dewDay.observedAt = ISO8601DateFormatter().date(from: "2026-10-27T02:00:00Z")!
        let samples: [(String, Double)] = [
            ("2026-10-26T23:00:00Z", 5),
            ("2026-10-27T01:00:00Z", 15), // Same New York day despite a different UTC date.
            ("2026-10-27T05:00:00Z", -99), // Tomorrow locally; exclude it.
            ("2026-10-27T00:00:00Z", .nan)
        ]
        dewDay.dailyForecast = samples.map { date, value in
            DewPointForecastPoint(date: ISO8601DateFormatter().date(from: date)!,
                                  dewPointCelsius: value, temperatureCelsius: 20, humidity: 0.5)
        }
        precondition(dewDay.observedDayDewPointRange == 5...15)
        precondition(DayTimelineMetric.dewPoint.widgetDayRange(for: dewDay) == 5...15)
        dewDay.dailyForecast = []
        precondition(DayTimelineMetric.dewPoint.widgetDayRange(for: dewDay) == nil)
        dewDay.dailyForecast = [DewPointForecastPoint(date: dewDay.observedAt,
            dewPointCelsius: 10, temperatureCelsius: 20, humidity: 0.5)]
        precondition(dewDay.observedDayDewPointRange == 10...10)
        precondition(WeatherRangeScale(values: [10, 10]).fraction(for: 10).isFinite)

        let sample = DewPointWidgetLoader.sampleReading
        precondition(sample.dailyWeather?.count == 10, "Widget gallery previews need real-shaped daily summaries")
        precondition(WeatherDashboardForecast(reading: sample).days.dropFirst().prefix(7).allSatisfy { $0.weather != nil })
        print("Widget metric tests passed")
    }
}
