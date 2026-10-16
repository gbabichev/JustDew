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

        let sample = DewPointWidgetLoader.sampleReading
        precondition(sample.dailyWeather?.count == 10, "Widget gallery previews need real-shaped daily summaries")
        precondition(WeatherDashboardForecast(reading: sample).days.dropFirst().prefix(7).allSatisfy { $0.weather != nil })
        print("Widget metric tests passed")
    }
}
