#if os(iOS) || os(macOS)
import SwiftUI
import WeatherKit

struct WeatherDetailsPresentation: ViewModifier {
    let reading: DewPointReading?
    @State private var showsDetails = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if let reading {
            Button {
                showsDetails = true
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens hourly precipitation, wind, and UV details")
            .sheet(isPresented: $showsDetails) {
                #if os(macOS)
                MacHourlyWeatherDetailsView(reading: reading)
                #else
                HourlyWeatherDetailsView(reading: reading)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                #endif
            }
        } else {
            content
        }
    }
}

private struct HourlyWeatherDetailsView: View {
    let reading: DewPointReading
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let forecast = HourlyWeatherForecast(reading: reading, referenceDate: context.date)
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reading.location.compactDisplayName).font(.headline)
                            Text("Next 24 hours · local time")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    if forecast.hasDetails {
                        ForEach(forecast.days) { day in
                            Section {
                                ForEach(day.hours) { hour in
                                    HourlyWeatherDetailRow(hour: hour, calendar: reading.forecastCalendar,
                                                          referenceDate: context.date)
                                }
                            } header: {
                                Text(DewPointFormatters.forecastDayLabel(day.date, relativeTo: context.date,
                                                                       calendar: reading.forecastCalendar))
                            }
                        }
                    } else {
                        ContentUnavailableView("Hourly Details Unavailable", systemImage: "cloud",
                            description: Text("Hourly details will appear after the next weather update."))
                    }
                    Section {
                        Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt, timeZone: reading.forecastCalendar.timeZone, includesDate: true))")
                        Link("Data from \(DewPointConfiguration.appleWeatherTrademark)",
                             destination: DewPointConfiguration.appleWeatherLegalAttributionURL)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Hourly Weather")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(idealWidth: 520, idealHeight: 650)
    }
}

private struct HourlyWeatherDetailRow: View {
    let hour: HourlyWeatherForecast.Hour
    let calendar: Calendar
    let referenceDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                if hour.start <= referenceDate && referenceDate < hour.end {
                    Text("Now").font(.headline)
                } else {
                    Text("\(DewPointFormatters.hourLabel(hour.start, timeZone: calendar.timeZone)) \(calendar.timeZone.abbreviation(for: hour.start) ?? "")")
                        .font(.headline)
                }
                Spacer(minLength: 8)
                if let weather = hour.point.weather {
                    Image(systemName: weather.symbolName)
                        .accessibilityLabel(weather.condition)
                }
                Text(DewPointFormatters.temperature(hour.point.temperature))
                    .font(.headline.monospacedDigit())
            }
            if let weather = hour.point.weather {
                HourlyWeatherMetrics(weather: weather)
            } else {
                Text("Details unavailable for this hour")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

private struct HourlyWeatherMetrics: View {
    let weather: DewPointHourlyWeather
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            HourlyWeatherMetric(title: "Precipitation", symbol: "cloud.rain",
                value: weather.precipitationChance.isFinite && (0...1).contains(weather.precipitationChance)
                    ? DewPointFormatters.percent(weather.precipitationChance) : "—")
            VStack(alignment: .leading, spacing: 3) {
                HourlyWeatherMetric(title: "Wind", symbol: "wind",
                                    value: DewPointFormatters.windSpeed(weather.windSpeedMetersPerSecond))
                if weather.windSpeedMetersPerSecond > 0,
                   let direction = Wind.CompassDirection(rawValue: weather.windDirection) {
                    Text("From \(direction.abbreviation)")
                        .accessibilityLabel("Wind from \(direction.description)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if let gust = weather.windGustMetersPerSecond, gust.isFinite, gust > weather.windSpeedMetersPerSecond {
                    Text("Gusts \(DewPointFormatters.windSpeed(gust))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                HourlyWeatherMetric(title: "UV Index", symbol: "sun.max",
                                    value: weather.uvIndex >= 0 ? weather.uvIndex.formatted() : "—")
                if weather.uvIndex >= 0, let category = UVIndex.ExposureCategory(rawValue: weather.uvCategory) {
                    Text(category.description).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HourlyWeatherMetric: View {
    let title: LocalizedStringKey
    let symbol: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
#endif
