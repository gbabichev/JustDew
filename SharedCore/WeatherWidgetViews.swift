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
        let days = Array(forecast.days.dropFirst().prefix(7))
        VStack(alignment: .leading, spacing: 6) {
            if combined {
                HStack(spacing: 8) {
                    Text("Day").frame(width: 36, alignment: .leading)
                    Text("Weather").frame(maxWidth: .infinity)
                    Text("Dew Point").frame(maxWidth: .infinity)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryColor)
            }
            if combined || days.contains(where: { $0.weather != nil }) {
                ForEach(days) { day in
                    HStack(spacing: combined ? 8 : 6) {
                        Text(DewPointFormatters.forecastDayLabel(day.date, relativeTo: reading.observedAt,
                                                               calendar: reading.forecastCalendar))
                            .font(.caption2)
                            .foregroundStyle(secondaryColor)
                            .lineLimit(1)
                            .frame(width: combined ? 36 : 46, alignment: .leading)
                        if !combined {
                            Image(systemName: day.weather?.symbolName ?? "questionmark")
                                .font(.caption2)
                                .foregroundStyle(secondaryColor)
                                .frame(width: 16)
                        }
                        WidgetForecastRange(low: day.weather?.lowTemperatureCelsius,
                                            high: day.weather?.highTemperatureCelsius,
                                            scale: forecast.temperatureScale, metric: .temperature,
                                            primaryColor: primaryColor, usesColor: usesColor)
                        if combined {
                            WidgetForecastRange(low: day.lowDewPointCelsius, high: day.highDewPointCelsius,
                                                scale: forecast.dewPointScale, metric: .dewPoint,
                                                primaryColor: primaryColor, usesColor: usesColor)
                        }
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
    private var isSmall: Bool { family == .systemSmall }
    private var usesColor: Bool {
        #if os(macOS)
        renderingMode == .fullColor
        #else
        renderingMode != .vibrant
        #endif
    }

    var body: some View {
        Group {
            if let reading = entry.reading {
                VStack(alignment: .leading, spacing: isSmall ? 5 : 7) {
                    HStack(spacing: 6) {
                        DewPointWidgetLocationText(location: reading.location)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                        Image(systemName: reading.symbolName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(reading.condition)
                    }
                    HStack(alignment: .top, spacing: isSmall ? 10 : 18) {
                        CombinedWidgetMetric(reading: reading, metric: .temperature,
                                             usesColor: usesColor, isSmall: isSmall)
                        CombinedWidgetMetric(reading: reading, metric: .dewPoint,
                                             usesColor: usesColor, isSmall: isSmall)
                    }
                    if family == .systemLarge || family == .systemExtraLarge {
                        Divider()
                        WeatherWidgetForecastRows(reading: reading, primaryColor: .primary,
                                                  secondaryColor: .secondary, usesColor: usesColor, combined: true)
                    } else {
                        Text(reading.condition)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt, timeZone: reading.forecastCalendar.timeZone))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Weather + Dew Point", systemImage: "cloud.sun")
                        .font(.caption.weight(.semibold))
                    Text(entry.message ?? "Choose Location")
                        .font(.caption)
                        .lineLimit(3)
                }
            }
        }
        .padding(isSmall ? 12 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            if entry.alwaysDark {
                Color(red: 0.07, green: 0.08, blue: 0.10)
            } else {
                Rectangle().fill(.fill.tertiary)
            }
        }
        .environment(\.colorScheme, entry.alwaysDark ? .dark : colorScheme)
    }
}

private struct CombinedWidgetMetric: View {
    let reading: DewPointReading
    let metric: DayTimelineMetric
    let usesColor: Bool
    let isSmall: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metric.widgetTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                .font(.system(size: isSmall ? 26 : 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(usesColor ? metric.color(forCelsius: metric.currentValue(in: reading).value) : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .accessibilityLabel(Text(metric.widgetTitle))
                .accessibilityValue(DewPointFormatters.temperature(metric.currentValue(in: reading)))
            DewPointDayTimelineView(reading: reading, showsLabels: false,
                                   trackHeight: isSmall ? 3 : 5, markerSize: isSmall ? 7 : 10,
                                   usesComfortColor: usesColor, monochromeColor: .secondary, metric: metric)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
