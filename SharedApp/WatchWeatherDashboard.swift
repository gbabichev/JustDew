#if os(watchOS)
import SwiftUI

struct WatchWeatherDashboard: View {
    let reading: DewPointReading?
    let isLoading: Bool
    let errorMessage: String?
    let refresh: () async -> Void

    var body: some View {
        Form {
            if let reading {
                let forecast = WeatherDashboardForecast(reading: reading)
                Section("Dew Point Now") {
                    WatchCurrentDewPoint(reading: reading)
                    NavigationLink {
                        WatchDailyForecast(reading: reading, metric: .dewPoint)
                    } label: {
                        Label("10-Day Dew Point", systemImage: "drop.degreesign")
                    }
                }
                Section("Weather Now") {
                    WatchCurrentWeather(reading: reading, today: forecast.days.first?.weather)
                    NavigationLink {
                        WatchDailyForecast(reading: reading, metric: .temperature)
                    } label: {
                        Label("10-Day Weather", systemImage: "calendar")
                    }
                }
                Section {
                    Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Link("Data from \(DewPointConfiguration.appleWeatherTrademark)",
                         destination: DewPointConfiguration.appleWeatherLegalAttributionURL)
                        .font(.caption2)
                }
            } else {
                Text("No Weather Data")
                    .foregroundStyle(.secondary)
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Section {
                if isLoading {
                    ProgressView("Refreshing")
                } else {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await refresh() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .refreshable { await refresh() }
    }
}

private struct WatchCurrentDewPoint: View {
    let reading: DewPointReading

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(DewPointFormatters.temperature(reading.dewPoint))
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DewPointComfortScale.color(for: reading.dewPointCelsius))
            Label("Humidity \(DewPointFormatters.percent(reading.humidity))", systemImage: "humidity")
                .font(.caption)
                .foregroundStyle(.secondary)
            DewPointDayTimelineView(reading: reading, showsLabels: false, trackHeight: 5, markerSize: 11)
        }
        .padding(.vertical, 4)
    }
}

private struct WatchCurrentWeather: View {
    let reading: DewPointReading
    let today: WeatherForecastDay?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(DewPointFormatters.temperature(reading.temperature))
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Spacer(minLength: 4)
                Image(systemName: reading.symbolName)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
            }
            Text(reading.condition)
                .font(.subheadline)
            if let feelsLike = reading.apparentTemperatureCelsius {
                Text("Feels like \(DewPointFormatters.temperature(Measurement(value: feelsLike, unit: .celsius)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let today {
                WatchTemperatureExtremes(low: today.lowTemperatureCelsius, high: today.highTemperatureCelsius)
                Label("\(DewPointFormatters.percent(today.precipitationChance)) chance today", systemImage: "cloud.rain")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            DewPointDayTimelineView(reading: reading, showsLabels: false, trackHeight: 5,
                                    markerSize: 11, metric: .temperature)
        }
        .padding(.vertical, 4)
    }
}

private struct WatchDailyForecast: View {
    let reading: DewPointReading
    let metric: DayTimelineMetric

    var body: some View {
        let forecast = WeatherDashboardForecast(reading: reading)
        List(forecast.days) { day in
            WatchDailyForecastRow(day: day, calendar: reading.forecastCalendar, metric: metric)
        }
        .navigationTitle(metric == .dewPoint ? Text("10-Day Dew Point") : Text("10-Day Weather"))
    }
}

private struct WatchDailyForecastRow: View {
    let day: WeatherDashboardDay
    let calendar: Calendar
    let metric: DayTimelineMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DewPointFormatters.forecastDayLabel(day.date, relativeTo: Date(), calendar: calendar))
                .font(.headline)
            if metric == .dewPoint {
                if let low = day.lowDewPointCelsius, let high = day.highDewPointCelsius {
                    WatchTemperatureExtremes(low: low, high: high)
                    if day.hasPartialDewPoint {
                        Text("Partial forecast").font(.caption2).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Forecast unavailable").font(.caption).foregroundStyle(.secondary)
                }
            } else if let weather = day.weather {
                Label(weather.condition, systemImage: weather.symbolName)
                    .font(.caption)
                WatchTemperatureExtremes(low: weather.lowTemperatureCelsius, high: weather.highTemperatureCelsius)
                Label("\(DewPointFormatters.percent(weather.precipitationChance)) rain chance", systemImage: "cloud.rain")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Forecast unavailable").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct WatchTemperatureExtremes: View {
    let low: Double
    let high: Double

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Label(DewPointFormatters.temperature(Measurement(value: high, unit: .celsius)), systemImage: "arrow.up")
                Label(DewPointFormatters.temperature(Measurement(value: low, unit: .celsius)), systemImage: "arrow.down")
            }
            VStack(alignment: .leading, spacing: 4) {
                Label(DewPointFormatters.temperature(Measurement(value: high, unit: .celsius)), systemImage: "arrow.up")
                Label(DewPointFormatters.temperature(Measurement(value: low, unit: .celsius)), systemImage: "arrow.down")
            }
        }
        .font(.caption)
        .monospacedDigit()
        .accessibilityLabel("High \(DewPointFormatters.temperature(Measurement(value: high, unit: .celsius))), low \(DewPointFormatters.temperature(Measurement(value: low, unit: .celsius)))")
    }
}
#endif
