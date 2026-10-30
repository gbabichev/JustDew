#if os(iOS) || os(macOS)
import SwiftUI
import WeatherKit

enum HourlyUVStyle {
    static func color(for index: Int, colorScheme: ColorScheme) -> Color {
        switch index {
        case ..<0: .secondary
        case 0...2: colorScheme == .dark ? .green : Color(red: 0.16, green: 0.43, blue: 0.22)
        // Darker yellow and orange keep small readings legible on light row backgrounds.
        case 3...5: colorScheme == .dark ? .yellow : Color(red: 0.55, green: 0.40, blue: 0)
        case 6...7: colorScheme == .dark ? .orange : Color(red: 0.72, green: 0.30, blue: 0)
        case 8...10: .red
        default: .purple
        }
    }
}

struct HourlyUVProtectionNote: View {
    var body: some View {
        Text("UV 3+: use sunscreen, cover up, and seek shade.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

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

#if os(iOS)
private struct HourlyWeatherDetailsView: View {
    let reading: DewPointReading
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var cityName: String {
        reading.location.compactDisplayName.split(separator: ",", maxSplits: 1).first.map(String.init)
            ?? reading.location.compactDisplayName
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let forecast = HourlyWeatherForecast(reading: reading, referenceDate: context.date)
                List {
                    if forecast.hasDetails {
                        ForEach(forecast.days) { day in
                            Section {
                                ForEach(day.hours.enumerated(), id: \.element.id) { index, hour in
                                    HourlyWeatherDetailRow(hour: hour, calendar: reading.forecastCalendar,
                                                          referenceDate: context.date)
                                        .listRowInsets(EdgeInsets(top: dynamicTypeSize.isAccessibilitySize ? 12 : 8,
                                                                  leading: 16,
                                                                  bottom: dynamicTypeSize.isAccessibilitySize ? 12 : 8,
                                                                  trailing: 16))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(index.isMultiple(of: 2)
                                            ? Color(uiColor: .secondarySystemGroupedBackground)
                                            : Color(uiColor: .systemGroupedBackground))
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
                        HourlyUVProtectionNote()
                        Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt, timeZone: reading.forecastCalendar.timeZone, includesDate: true))")
                        Link("Data from \(DewPointConfiguration.appleWeatherTrademark)",
                             destination: DewPointConfiguration.appleWeatherLegalAttributionURL)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .listStyle(.insetGrouped)
                .navigationSubtitle(Text("Next 24 hours · \(DewPointFormatters.timeZoneLabel(context.date, timeZone: reading.forecastCalendar.timeZone))"))
            }
            .navigationTitle(Text("\(cityName) Weather"))
            .navigationBarTitleDisplayMode(.inline)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        layout {
            HourlyWeatherTimeLabel(hour: hour, calendar: calendar, referenceDate: referenceDate)
                .fixedSize(horizontal: true, vertical: false)
            if let weather = hour.point.weather {
                HourlyWeatherMetrics(weather: weather)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Details unavailable for this hour")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 6) {
                if let weather = hour.point.weather {
                    Image(systemName: weather.symbolName)
                        .accessibilityLabel(weather.condition)
                }
                Text(DewPointFormatters.temperature(hour.point.temperature))
                    .foregroundStyle(WeatherTemperatureColors.color(forCelsius: hour.point.temperatureCelsius))
                    .monospacedDigit()
            }
            .font(dynamicTypeSize.isAccessibilitySize ? .headline : .subheadline.weight(.semibold))
            .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct HourlyWeatherTimeLabel: View {
    let hour: HourlyWeatherForecast.Hour
    let calendar: Calendar
    let referenceDate: Date
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if hour.start <= referenceDate && referenceDate < hour.end {
                Text("Now")
            } else {
                Text(DewPointFormatters.hourlyDetailsTime(hour.start, referenceDate: referenceDate, timeZone: calendar.timeZone))
            }
        }
        .font(dynamicTypeSize.isAccessibilitySize ? .headline : .subheadline.weight(.semibold))
    }
}

private struct HourlyWeatherMetrics: View {
    let weather: DewPointHourlyWeather
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        layout {
            HourlyWeatherMetric(title: "Precipitation", symbol: "cloud.rain",
                compact: !dynamicTypeSize.isAccessibilitySize,
                value: weather.precipitationChance.isFinite && (0...1).contains(weather.precipitationChance)
                    ? DewPointFormatters.percent(weather.precipitationChance) : "—")
            HourlyWeatherMetric(title: "Wind", symbol: "wind",
                                compact: !dynamicTypeSize.isAccessibilitySize, value: windValue,
                                detail: gustDetail, spokenValue: windAccessibilityValue)
            HourlyWeatherMetric(title: "UV Index", symbol: "sun.max",
                                compact: !dynamicTypeSize.isAccessibilitySize, value: uvValue,
                                detail: uvDetail,
                                tint: HourlyUVStyle.color(for: weather.uvIndex, colorScheme: colorScheme))
        }
    }

    private var gustDetail: String? {
        guard let gust = weather.windGustMetersPerSecond, gust.isFinite,
              gust > weather.windSpeedMetersPerSecond else { return nil }
        return String(localized: "Gusts \(DewPointFormatters.windSpeed(gust))")
    }

    private var uvDetail: String? {
        guard weather.uvIndex >= 0,
              let category = UVIndex.ExposureCategory(rawValue: weather.uvCategory) else { return nil }
        return category.description
    }

    private var uvValue: String {
        guard weather.uvIndex >= 0 else { return "—" }
        return dynamicTypeSize.isAccessibilitySize
            ? weather.uvIndex.formatted()
            : String(localized: "UV \(weather.uvIndex.formatted())")
    }

    private var windValue: String {
        let speed = DewPointFormatters.windSpeed(weather.windSpeedMetersPerSecond)
        guard weather.windSpeedMetersPerSecond > 0,
              let direction = Wind.CompassDirection(rawValue: weather.windDirection) else { return speed }
        return "\(speed) \(direction.abbreviation)"
    }

    private var windAccessibilityValue: String {
        let speed = DewPointFormatters.windSpeed(weather.windSpeedMetersPerSecond)
        guard weather.windSpeedMetersPerSecond > 0,
              let direction = Wind.CompassDirection(rawValue: weather.windDirection) else { return speed }
        return String(localized: "\(speed), from \(direction.description)")
    }
}

private struct HourlyWeatherMetric: View {
    let title: LocalizedStringKey
    let symbol: String
    let compact: Bool
    let value: String
    var detail: String? = nil
    var spokenValue: String? = nil
    var tint: Color? = nil

    var body: some View {
        Group {
            if compact {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: symbol)
                        .foregroundStyle(tint ?? .secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(value)
                            .foregroundStyle(tint ?? .primary)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        if let detail {
                            Text(detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
                .font(.caption)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .foregroundStyle(tint ?? .primary)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    if let detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: Text {
        let value = spokenValue ?? value
        if let detail { return Text("\(value). \(detail)") }
        return Text(value)
    }
}
#endif
#endif
