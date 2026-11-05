#if os(watchOS)
import SwiftUI
import WeatherKit

struct WatchHourlyWeatherForecast: View {
    let reading: DewPointReading

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let forecast = HourlyWeatherForecast(reading: reading, referenceDate: context.date)
            List {
                if forecast.days.isEmpty {
                    Text("Hourly details will appear after the next weather update.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(forecast.days) { day in
                        Section(DewPointFormatters.forecastDayLabel(day.date, relativeTo: context.date,
                                                                  calendar: reading.forecastCalendar)) {
                            ForEach(day.hours) { hour in
                                WatchHourlyWeatherRow(hour: hour, calendar: reading.forecastCalendar,
                                                      referenceDate: context.date)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Hourly Weather")
    }
}

private struct WatchHourlyWeatherRow: View {
    let hour: HourlyWeatherForecast.Hour
    let calendar: Calendar
    let referenceDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if hour.start <= referenceDate && referenceDate < hour.end {
                    Text("Now")
                } else {
                    Text(DewPointFormatters.hourlyDetailsTime(hour.start, referenceDate: referenceDate,
                                                            timeZone: calendar.timeZone))
                }
                Spacer(minLength: 4)
                Text(DewPointFormatters.temperature(hour.point.temperature))
                    .foregroundStyle(WeatherTemperatureColors.color(forCelsius: hour.point.temperature.value))
                    .monospacedDigit()
            }
            .font(.headline)

            if let weather = hour.point.weather {
                Label {
                    Text(weather.localizedCondition)
                } icon: {
                    Image(systemName: weather.symbolName)
                        .modifier(WeatherConditionSymbolStyle(symbolName: weather.symbolName))
                }
                Label(DewPointFormatters.percent(weather.precipitationChance), systemImage: "cloud.rain")
                    .accessibilityLabel("Precipitation")
                    .accessibilityValue(DewPointFormatters.percent(weather.precipitationChance))
                Label {
                    HStack(spacing: 4) {
                        Text(DewPointFormatters.windSpeed(weather.windSpeedMetersPerSecond))
                        if let direction = Wind.CompassDirection(rawValue: weather.windDirection),
                           weather.windSpeedMetersPerSecond > 0 {
                            Text(direction.abbreviation)
                        }
                    }
                } icon: {
                    Image(systemName: "wind")
                }
                if let gust = weather.windGustMetersPerSecond, gust.isFinite,
                   gust > weather.windSpeedMetersPerSecond {
                    Text("Gusts \(DewPointFormatters.windSpeed(gust))")
                }
                if weather.uvIndex >= 0 {
                    Label("UV \(weather.uvIndex.formatted())", systemImage: "sun.max")
                }
            }
        }
        .font(.caption)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
#endif
