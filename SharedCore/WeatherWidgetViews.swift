#if os(iOS) || os(macOS)
import SwiftUI
import WidgetKit

/// The weather-only large widget and the combined large widget use the same daily data.
struct WeatherWidgetForecastRows: View {
    let reading: DewPointReading
    let primaryColor: Color
    let secondaryColor: Color
    let usesColor: Bool
    var combined = false

    var body: some View {
        let forecast = WeatherDashboardForecast(reading: reading)
        let days = Array(forecast.days.dropFirst().filter {
            $0.hasWeatherForecast && (!combined || $0.hasDewPointForecast)
        }.prefix(7))
        VStack(alignment: .leading, spacing: 6) {
            if combined && !days.isEmpty {
                HStack(spacing: 8) {
                    Text("Day").frame(width: 36, alignment: .leading)
                    Text("Dew Point").frame(maxWidth: .infinity)
                    Text("Weather").frame(maxWidth: .infinity)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryColor)
            }
            if !days.isEmpty {
                ForEach(days) { day in
                    HStack(spacing: combined ? 8 : 6) {
                        Text(DewPointFormatters.forecastDayLabel(day.date, relativeTo: reading.observedAt,
                                                               calendar: reading.forecastCalendar))
                            .font(.caption2)
                            .foregroundStyle(secondaryColor)
                            .lineLimit(1)
                            .frame(width: combined ? 36 : 46, alignment: .leading)
                        if !combined, let weather = day.weather {
                            Image(systemName: weather.symbolName)
                                .font(.caption2)
                                .foregroundStyle(secondaryColor)
                                .frame(width: 16)
                        }
                        if combined {
                            WidgetForecastRange(low: day.lowDewPointCelsius, high: day.highDewPointCelsius,
                                                scale: forecast.dewPointScale, metric: .dewPoint,
                                                primaryColor: primaryColor, usesColor: usesColor)
                        }
                        WidgetForecastRange(low: day.weather?.lowTemperatureCelsius,
                                            high: day.weather?.highTemperatureCelsius,
                                            scale: forecast.temperatureScale, metric: .temperature,
                                            primaryColor: primaryColor, usesColor: usesColor)
                    }
                }
            } else {
                Text("Forecast temporarily unavailable")
                    .font(.caption2)
                    .foregroundStyle(secondaryColor)
            }
        }
    }
}

private struct WidgetForecastRange: View {
    let low: Double?
    let high: Double?
    let scale: WeatherRangeScale
    let metric: DayTimelineMetric
    let primaryColor: Color
    let usesColor: Bool

    var body: some View {
        HStack(spacing: 3) {
            if let low, let high, low.isFinite, high.isFinite {
                Text(degrees(low))
                    .frame(width: 25, alignment: .trailing)
                GeometryReader { geometry in
                    let width = max(geometry.size.width, 1)
                    let start = scale.fraction(for: low) * width
                    let end = scale.fraction(for: high) * width
                    let barWidth = min(width, max(end - start, 3))
                    ZStack(alignment: .leading) {
                        Capsule().fill(primaryColor.opacity(0.12))
                        Capsule()
                            .fill(LinearGradient(colors: colors(low: low, high: high),
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: barWidth)
                            .offset(x: min(start, width - barWidth))
                    }
                }
                .frame(height: 5)
                .accessibilityHidden(true)
                Text(degrees(high))
                    .frame(width: 25, alignment: .trailing)
            } else {
                Text("—").frame(maxWidth: .infinity)
            }
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(primaryColor)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(metric.widgetTitle))
        .accessibilityValue(accessibilityValue)
    }

    private func degrees(_ value: Double) -> String {
        "\(DewPointFormatters.temperatureValue(Measurement(value: value, unit: .celsius)))°"
    }

    private func colors(low: Double, high: Double) -> [Color] {
        usesColor ? [metric.color(forCelsius: low), metric.color(forCelsius: high)] : [primaryColor.opacity(0.7)]
    }

    private var accessibilityValue: Text {
        guard let low, let high else { return Text("Forecast unavailable") }
        return Text("Low \(DewPointFormatters.temperature(Measurement(value: low, unit: .celsius))), high \(DewPointFormatters.temperature(Measurement(value: high, unit: .celsius)))")
    }
}

struct CombinedWeatherWidgetEntryView: View {
    let entry: DewPointWidgetEntry
    private let familyOverride: WidgetFamily?
    @Environment(\.widgetFamily) private var environmentFamily
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme

    init(entry: DewPointWidgetEntry, family: WidgetFamily? = nil) {
        self.entry = entry
        familyOverride = family
    }

    private var family: WidgetFamily { familyOverride ?? environmentFamily }
    private var usesColor: Bool {
        #if os(macOS)
        renderingMode == .fullColor
        #else
        renderingMode != .vibrant
        #endif
    }

    var body: some View {
        Group {
            #if os(iOS)
            if isAccessory {
                CombinedAccessoryWidgetContent(entry: entry, family: family)
            } else {
                CombinedHomeWidgetContent(entry: entry, family: family, usesColor: usesColor)
            }
            #else
            CombinedHomeWidgetContent(entry: entry, family: family, usesColor: usesColor)
            #endif
        }
        .padding(DewPointWidgetLayout.padding(for: family))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isAccessory ? .center : .topLeading)
        .containerBackground(for: .widget) {
            if entry.alwaysDark {
                Color(red: 0.07, green: 0.08, blue: 0.10)
            } else {
                Rectangle().fill(.fill.tertiary)
            }
        }
        .environment(\.colorScheme, entry.alwaysDark ? .dark : colorScheme)
    }

    private var isAccessory: Bool {
        #if os(iOS)
        family == .accessoryCircular || family == .accessoryRectangular || family == .accessoryInline
        #else
        false
        #endif
    }

}

private struct CombinedHomeWidgetContent: View {
    let entry: DewPointWidgetEntry
    let family: WidgetFamily
    let usesColor: Bool
    private var isSmall: Bool { family == .systemSmall }

    var body: some View {
        Group {
            if let reading = entry.reading {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .top, spacing: isSmall ? 10 : 18) {
                        CombinedWidgetMetric(reading: reading, metric: .dewPoint,
                                             usesColor: usesColor, isSmall: isSmall)
                        CombinedWidgetMetric(reading: reading, metric: .temperature,
                                             usesColor: usesColor, isSmall: isSmall)
                    }
                    DewPointWidgetLocationText(location: reading.location)
                        .font(isSmall ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if isSmall {
                        Text(reading.condition)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt, timeZone: reading.forecastCalendar.timeZone))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        HStack {
                            Text(reading.condition).lineLimit(1)
                            Text("Humidity \(DewPointFormatters.percent(reading.humidity))")
                            Spacer(minLength: 0)
                            Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt, timeZone: reading.forecastCalendar.timeZone))")
                                .lineLimit(1)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    if family == .systemLarge || family == .systemExtraLarge {
                        Divider()
                        WeatherWidgetForecastRows(reading: reading, primaryColor: .primary,
                                                  secondaryColor: .secondary, usesColor: usesColor, combined: true)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Dew Point + Weather", systemImage: "drop.degreesign.fill")
                        .font(.caption.weight(.semibold))
                    Text(entry.message ?? "Choose Location")
                        .font(.caption)
                        .lineLimit(3)
                }
            }
        }
    }
}

#if os(iOS)
private struct CombinedAccessoryWidgetContent: View {
    let entry: DewPointWidgetEntry
    let family: WidgetFamily

    var body: some View {
        if let reading = entry.reading {
            switch family {
            case .accessoryInline:
                Text("Dew \(DewPointFormatters.temperature(reading.dewPoint)) · Air \(DewPointFormatters.temperature(reading.temperature))")
            case .accessoryCircular:
                VStack(spacing: 3) {
                    CombinedAccessoryValue(reading: reading, metric: .dewPoint)
                    CombinedAccessoryValue(reading: reading, metric: .temperature)
                }
                .font(.caption.bold())
            default:
                ViewThatFits(in: .vertical) {
                    CombinedAccessoryRectangularContent(reading: reading, showsTimelines: true)
                        .fixedSize(horizontal: false, vertical: true)
                    CombinedAccessoryRectangularContent(reading: reading, showsTimelines: false)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            }
        } else {
            if family == .accessoryInline {
                Text("Dew + Weather: \(entry.message ?? "Choose Location")")
            } else {
                VStack(spacing: 2) {
                    Text("Dew + Weather").font(.caption2.bold())
                    Text(entry.message ?? "Choose Location").font(.caption2)
                }
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            }
        }
    }
}

private struct CombinedAccessoryRectangularContent: View {
    let reading: DewPointReading
    let showsTimelines: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 10) {
                CombinedAccessoryMetric(reading: reading, metric: .dewPoint, showsTimeline: showsTimelines)
                CombinedAccessoryMetric(reading: reading, metric: .temperature, showsTimeline: showsTimelines)
            }
            HStack(spacing: 4) {
                DewPointWidgetLocationText(location: reading.location)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Image(systemName: reading.symbolName)
                    .accessibilityLabel(reading.condition)
            }
            .font(.system(size: showsTimelines ? 10 : 9))
            .foregroundStyle(.secondary)
        }
    }
}

private struct CombinedAccessoryValue: View {
    let reading: DewPointReading
    let metric: DayTimelineMetric

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: metric.widgetSymbol)
                .frame(width: 12)
            Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(metric.widgetTitle))
        .accessibilityValue(DewPointFormatters.temperature(metric.currentValue(in: reading)))
    }
}

private struct CombinedAccessoryMetric: View {
    let reading: DewPointReading
    let metric: DayTimelineMetric
    let showsTimeline: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(metric.widgetTitle)
                .font(.system(size: showsTimeline ? 10 : 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                .font(.system(size: showsTimeline ? 16 : 14, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if showsTimeline {
                DewPointDayTimelineView(reading: reading, showsLabels: false,
                                       trackHeight: 2, markerSize: 5,
                                       usesComfortColor: false, monochromeColor: .secondary, metric: metric)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(metric.widgetTitle))
        .accessibilityValue(DewPointFormatters.temperature(metric.currentValue(in: reading)))
    }
}
#endif

private struct CombinedWidgetMetric: View {
    let reading: DewPointReading
    let metric: DayTimelineMetric
    let usesColor: Bool
    let isSmall: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 6 : 5) {
            HStack(spacing: isSmall ? 4 : 6) {
                if !isSmall {
                    Image(systemName: metric.widgetSymbol)
                        .foregroundStyle(usesColor ? metric.color(forCelsius: metric.currentValue(in: reading).value) : .secondary)
                }
                Text(metric.widgetTitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if metric == .temperature && !isSmall {
                    Spacer(minLength: 0)
                    Image(systemName: reading.symbolName)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(reading.condition)
                }
            }
            .font(isSmall ? .caption2 : .caption)
            Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                .font(.system(size: isSmall ? 28 : 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(usesColor ? metric.color(forCelsius: metric.currentValue(in: reading).value) : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .accessibilityLabel(Text(metric.widgetTitle))
                .accessibilityValue(DewPointFormatters.temperature(metric.currentValue(in: reading)))
            DewPointDayTimelineView(reading: reading, showsLabels: false,
                                   trackHeight: isSmall ? 5 : 7, markerSize: isSmall ? 10 : 14,
                                   usesComfortColor: usesColor, monochromeColor: .secondary, metric: metric)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
