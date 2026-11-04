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
                        VStack(alignment: .leading, spacing: 8) {
                            HourlyUVProtectionNote()
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 16) {
                                    updateTime
                                    Spacer(minLength: 0)
                                    attribution
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    updateTime
                                    attribution
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowSeparator(.hidden)
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

    private var updateTime: some View {
        Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt, timeZone: reading.forecastCalendar.timeZone, includesDate: true))")
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attribution: some View {
        Link("Data from \(DewPointConfiguration.appleWeatherTrademark)",
             destination: DewPointConfiguration.appleWeatherLegalAttributionURL)
            .fixedSize()
    }
}

private struct HourlyWeatherDetailRow: View {
    let hour: HourlyWeatherForecast.Hour
    let calendar: Calendar
    let referenceDate: Date
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        timeLabel
                        Spacer(minLength: 12)
                        temperature
                    }
                    if let weather = hour.point.weather {
                        HourlyWeatherMetrics(weather: weather, part: .all)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        unavailable
                    }
                }
            } else {
                if let weather = hour.point.weather {
                    // Hour | Weather | UV | Rain | Wind, same widths in every row.
                    HourlyMetricColumns {
                        timeLabel
                            .frame(maxWidth: .infinity, alignment: .leading)
                        temperature
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HourlyWeatherMetrics(weather: weather, part: .uv)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HourlyWeatherMetrics(weather: weather, part: .rain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HourlyWeatherMetrics(weather: weather, part: .wind)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            timeLabel
                            Spacer(minLength: 12)
                            temperature
                        }
                        unavailable
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var timeLabel: some View {
        HourlyWeatherTimeLabel(hour: hour, calendar: calendar, referenceDate: referenceDate)
    }

    private var temperature: some View {
        HStack(spacing: 8) {
            if let weather = hour.point.weather {
                Image(systemName: weather.symbolName)
                    .modifier(WeatherConditionSymbolStyle(symbolName: weather.symbolName))
                    .accessibilityLabel(weather.condition)
            }
            Text(DewPointFormatters.temperature(hour.point.temperature))
                .foregroundStyle(WeatherTemperatureColors.color(forCelsius: hour.point.temperatureCelsius))
                .monospacedDigit()
        }
        .font(.title3.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var unavailable: some View {
        Text("Details unavailable for this hour")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

private struct HourlyWeatherTimeLabel: View {
    let hour: HourlyWeatherForecast.Hour
    let calendar: Calendar
    let referenceDate: Date
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let isNow = hour.start <= referenceDate && referenceDate < hour.end
        Group {
            if isNow {
                Text("Now")
            } else {
                Text(DewPointFormatters.hourlyDetailsTime(hour.start, referenceDate: referenceDate, timeZone: calendar.timeZone))
            }
        }
        .font(dynamicTypeSize.isAccessibilitySize ? .headline : .body.weight(isNow ? .semibold : .regular))
        .foregroundStyle(isNow ? Color.accentColor : Color.primary)
    }
}

private struct HourlyWeatherMetrics: View {
    let weather: DewPointHourlyWeather
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    enum Part { case all, rain, uv, wind }
    var part: Part = .all

    @ViewBuilder
    var body: some View {
        switch part {
        case .rain:
            HourlyWeatherMetric(title: "Precipitation", symbol: "drop.fill", compact: true,
                                value: rainValue, iconTint: .blue)
        case .uv:
            HourlyWeatherMetric(title: "UV Index", symbol: "", compact: true,
                                value: uvValue, detail: uvDetail,
                                tint: HourlyUVStyle.color(for: weather.uvIndex, colorScheme: colorScheme),
                                showsDetail: false)
        case .wind:
            HourlyWeatherMetric(title: "Wind", symbol: "wind", compact: true,
                                value: DewPointFormatters.windSpeed(weather.windSpeedMetersPerSecond),
                                detail: gustDetail, spokenValue: windAccessibilityValue,
                                showsDetail: false)
        case .all:
            VStack(alignment: .leading, spacing: 12) {
                HourlyWeatherMetric(title: "Precipitation", symbol: "cloud.rain", compact: false,
                                    value: rainValue)
                HourlyWeatherMetric(title: "Wind", symbol: "wind", compact: false,
                                    value: windValue, detail: gustDetail, spokenValue: windAccessibilityValue)
                HourlyWeatherMetric(title: "UV Index", symbol: "sun.max", compact: false,
                                    value: uvValue, detail: uvDetail,
                                    tint: HourlyUVStyle.color(for: weather.uvIndex, colorScheme: colorScheme))
            }
        }
    }

    private var rainValue: String {
        weather.precipitationChance.isFinite && (0...1).contains(weather.precipitationChance)
            ? DewPointFormatters.percent(weather.precipitationChance) : "—"
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

/// Splits the width into fixed proportions and centers each child vertically,
/// so every row's columns line up regardless of content.
private struct HourlyMetricColumns: Layout {
    private let weights: [CGFloat] = [0.16, 0.32, 0.15, 0.17, 0.20]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        let height = zip(subviews, weights).map { subview, weight in
            subview.sizeThatFits(ProposedViewSize(width: width * weight, height: nil)).height
        }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, weight) in zip(subviews, weights) {
            let width = bounds.width * weight
            subview.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                          proposal: ProposedViewSize(width: width, height: nil))
            x += width
        }
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
    var iconTint: Color? = nil
    var showsDetail = true
    var alignment: Alignment = .leading

    var body: some View {
        Group {
            if compact {
                HStack(spacing: 5) {
                    if !symbol.isEmpty {
                        Image(systemName: symbol)
                            .foregroundStyle(tint ?? iconTint ?? .secondary)
                            .imageScale(.small)
                    }
                    Text(value)
                        .foregroundStyle(tint ?? .secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .font(.subheadline)
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
        .frame(maxWidth: compact ? nil : .infinity, alignment: alignment)
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

#if DEBUG
#Preview("Hourly · narrow two-row layout", traits: .sizeThatFitsLayout) {
    HourlyWeatherDetailRow(hour: HourlyWeatherRowPreview.hour, calendar: .current,
                          referenceDate: HourlyWeatherRowPreview.hour.start)
        .padding(16)
        .frame(width: 288)
}

#Preview("Hourly · larger text", traits: .sizeThatFitsLayout) {
    HourlyWeatherDetailRow(hour: HourlyWeatherRowPreview.hour, calendar: .current,
                          referenceDate: HourlyWeatherRowPreview.hour.start)
        .padding(16)
        .frame(width: 320)
        .environment(\.dynamicTypeSize, .xxxLarge)
}

#Preview("Hourly · accessibility", traits: .sizeThatFitsLayout) {
    HourlyWeatherDetailRow(hour: HourlyWeatherRowPreview.hour, calendar: .current,
                          referenceDate: HourlyWeatherRowPreview.hour.start)
        .padding(16)
        .frame(width: 320)
        .environment(\.dynamicTypeSize, .accessibility2)
}

private enum HourlyWeatherRowPreview {
    static var hour: HourlyWeatherForecast.Hour {
        let date = Date()
        let weather = DewPointHourlyWeather(precipitationChance: 0.65,
            windSpeedMetersPerSecond: 12, windGustMetersPerSecond: 18,
            windDirection: "SSE", uvIndex: 11, uvCategory: "extreme",
            condition: "Rain", symbolName: "cloud.rain")
        let point = DewPointForecastPoint(date: date, dewPointCelsius: 18,
            temperatureCelsius: 28, humidity: 0.65, weather: weather)
        return HourlyWeatherForecast.Hour(start: date, end: date.addingTimeInterval(3_600), point: point)
    }
}
#endif
#endif
#endif
