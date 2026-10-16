#if os(macOS)
import SwiftUI
import WeatherKit

struct MacHourlyWeatherDetailsView: View {
    let reading: DewPointReading
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hourly Weather").font(.title2.weight(.semibold))
                Text("\(reading.location.compactDisplayName) · Next 24 hours · local time")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let forecast = HourlyWeatherForecast(reading: reading, referenceDate: context.date)
                let hours = forecast.days.flatMap(\.hours)
                if forecast.hasDetails {
                    MacHourlyWeatherTable(hours: hours, calendar: reading.forecastCalendar, referenceDate: context.date)
                } else {
                    ContentUnavailableView("Hourly Details Unavailable", systemImage: "cloud",
                        description: Text("Hourly details will appear after the next weather update."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt, timeZone: reading.forecastCalendar.timeZone, includesDate: true))")
                        .foregroundStyle(.secondary)
                    Link("Data from \(DewPointConfiguration.appleWeatherTrademark)",
                         destination: DewPointConfiguration.appleWeatherLegalAttributionURL)
                }
                .font(.caption)
                Spacer(minLength: 0)
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 680, idealWidth: 760, maxWidth: 900,
               minHeight: 420, idealHeight: 580, maxHeight: 760)
        .onExitCommand { dismiss() }
    }
}

private struct MacHourlyWeatherTable: View {
    let hours: [HourlyWeatherForecast.Hour]
    let calendar: Calendar
    let referenceDate: Date

    var body: some View {
        Table(hours) {
            TableColumn("Time") { hour in
                MacHourlyTimeCell(hour: hour, calendar: calendar, referenceDate: referenceDate)
            }
            .width(min: 90, ideal: 110, max: 140)
            TableColumn("Weather") { hour in
                MacHourlyConditionsCell(point: hour.point)
            }
            .width(min: 105, ideal: 140, max: 200)
            TableColumn("Precipitation") { hour in
                Text(precipitation(hour.point.weather?.precipitationChance))
                    .monospacedDigit()
            }
            .width(min: 80, ideal: 90, max: 110)
            TableColumn("Wind") { hour in
                MacHourlyWindCell(weather: hour.point.weather)
            }
            .width(min: 125, ideal: 145, max: 180)
            TableColumn("UV Index") { hour in
                MacHourlyUVCell(weather: hour.point.weather)
            }
            .width(min: 90, ideal: 100, max: 130)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .font(.callout)
    }

    private func precipitation(_ chance: Double?) -> String {
        guard let chance, chance.isFinite, (0...1).contains(chance) else { return "—" }
        return DewPointFormatters.percent(chance)
    }
}

private struct MacHourlyTimeCell: View {
    let hour: HourlyWeatherForecast.Hour
    let calendar: Calendar
    let referenceDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if hour.start <= referenceDate && referenceDate < hour.end {
                Text("Now").fontWeight(.semibold)
            } else {
                Text("\(DewPointFormatters.hourLabel(hour.start, timeZone: calendar.timeZone)) \(calendar.timeZone.abbreviation(for: hour.start) ?? "")")
                    .monospacedDigit()
            }
            Text(DewPointFormatters.forecastDayLabel(hour.start, relativeTo: referenceDate, calendar: calendar))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct MacHourlyConditionsCell: View {
    let point: DewPointForecastPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if let weather = point.weather {
                    Image(systemName: weather.symbolName)
                        .frame(width: 18)
                        .accessibilityHidden(true)
                }
                Text(DewPointFormatters.temperature(point.temperature))
                    .monospacedDigit()
            }
            if let weather = point.weather {
                Text(weather.condition)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(weather.condition)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MacHourlyWindCell: View {
    let weather: DewPointHourlyWeather?

    var body: some View {
        if let weather {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(DewPointFormatters.windSpeed(weather.windSpeedMetersPerSecond))
                        .monospacedDigit()
                    if weather.windSpeedMetersPerSecond > 0,
                       let direction = Wind.CompassDirection(rawValue: weather.windDirection) {
                        Text(direction.abbreviation)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("From \(direction.description)")
                    }
                }
                if let gust = weather.windGustMetersPerSecond, gust.isFinite, gust > weather.windSpeedMetersPerSecond {
                    Text("Gusts \(DewPointFormatters.windSpeed(gust))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            Text("—")
        }
    }
}

private struct MacHourlyUVCell: View {
    let weather: DewPointHourlyWeather?

    var body: some View {
        if let weather, weather.uvIndex >= 0 {
            VStack(alignment: .leading, spacing: 2) {
                Text(weather.uvIndex.formatted()).monospacedDigit()
                if let category = UVIndex.ExposureCategory(rawValue: weather.uvCategory) {
                    Text(category.description).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            Text("—")
        }
    }
}
#endif
