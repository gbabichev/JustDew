import SwiftUI
import WidgetKit

#if os(iOS) || os(macOS)
struct DewPointWidgetEntry: TimelineEntry {
    let date: Date
    let reading: DewPointReading?
    let message: String?
    var alwaysDark: Bool = false
}

extension DewPointWidgetEntry {
    static var previewReading: DewPointWidgetEntry {
        DewPointWidgetEntry(date: .now, reading: DewPointWidgetLoader.sampleReading, message: nil)
    }

    static var previewNeedsLocation: DewPointWidgetEntry {
        DewPointWidgetEntry(date: .now, reading: nil, message: "Choose Location")
    }
}

enum DewPointWidgetLayout {
    static func padding(for family: WidgetFamily) -> EdgeInsets {
        return switch family {
        #if os(iOS)
        case .systemSmall:
            EdgeInsets(top: 21, leading: 20, bottom: 14, trailing: 20)
        case .systemMedium:
            EdgeInsets(top: 25, leading: 20, bottom: 16, trailing: 20)
        case .systemLarge, .systemExtraLarge:
            EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20)
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            EdgeInsets()
        #endif
        #if os(macOS)
        default:
            EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18)
        #else
        default:
            EdgeInsets()
        #endif
        }
    }
}

struct JustDewWidgetEntryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var environmentFamily
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: DewPointWidgetEntry
    let metric: DayTimelineMetric
    private let familyOverride: WidgetFamily?

    init(entry: DewPointWidgetEntry, family: WidgetFamily? = nil, metric: DayTimelineMetric = .dewPoint) {
        self.entry = entry
        self.metric = metric
        familyOverride = family
    }

    var body: some View {
        Group {
            if let reading = entry.reading {
                content(for: reading)
            } else {
                unavailableContent
            }
        }
        .padding(widgetPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)
        .containerBackground(for: .widget) {
            if entry.alwaysDark {
                Color(red: 0.07, green: 0.08, blue: 0.10)
            } else {
                Rectangle().fill(.fill.tertiary)
            }
        }
        .environment(\.colorScheme, entry.alwaysDark ? .dark : colorScheme)
    }

    private var family: WidgetFamily {
        familyOverride ?? environmentFamily
    }

    private var contentAlignment: Alignment {
        switch family {
        #if os(iOS)
        case .accessoryCircular:
            .center
        case .accessoryRectangular:
            .leading
        #endif
        case .accessoryInline:
            .center
        default:
            .topLeading
        }
    }

    private var widgetPadding: EdgeInsets {
        if isLockScreenSquare {
            return EdgeInsets()
        }
        return DewPointWidgetLayout.padding(for: family)
    }

    private var isLockScreenSquare: Bool {
        #if os(iOS)
        family == .systemSmall && renderingMode == .vibrant
        #else
        false
        #endif
    }

    @ViewBuilder
    private func content(for reading: DewPointReading) -> some View {
        if isLockScreenSquare {
            DewPointLockScreenSquareContent(reading: reading, metric: metric)
        } else {
            standardContent(for: reading)
        }
    }

    @ViewBuilder
    private func standardContent(for reading: DewPointReading) -> some View {
        switch family {
        #if os(iOS)
        case .accessoryInline:
            DewPointInlineWidgetText(reading: reading, metric: metric)
                .foregroundStyle(primaryTextColor)
        case .accessoryCircular:
            VStack(spacing: 2) {
                Image(systemName: metric == .temperature ? reading.symbolName : (reading.location.mode == .current ? "location.fill" : metric.widgetSymbol))
                    .accessibilityLabel(reading.location.mode == .current ? Text("Current Location") : Text(metric.widgetTitle))
                Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                    .font(.caption.bold())
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(primaryTextColor)
        case .accessoryRectangular:
            DewPointAccessoryRectangularView(reading: reading, metric: metric)
        #endif
        case .systemLarge, .systemExtraLarge:
            DewPointLargeWidgetContent(
                reading: reading,
                primaryColor: primaryTextColor,
                secondaryColor: secondaryTextColor,
                valueColor: dewPointValueColor(for: reading),
                accentColor: comfortAccentColor(for: reading),
                usesComfortColor: showsComfortColor,
                metric: metric
            )
        case .systemMedium:
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: metric.widgetSymbol)
                            .foregroundStyle(comfortAccentColor(for: reading))
                        Text(metric.widgetTitle)
                            .foregroundStyle(secondaryTextColor)
                    }
                    Spacer()
                    Image(systemName: reading.symbolName)
                        .foregroundStyle(secondaryTextColor)
                }
                .font(.caption)

                Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(dewPointValueColor(for: reading))

                DewPointDayTimelineView(
                    reading: reading,
                    showsLabels: false,
                    trackHeight: 7,
                    markerSize: 14,
                    usesComfortColor: showsComfortColor,
                    monochromeColor: secondaryTextColor,
                    metric: metric
                )

                DewPointWidgetLocationText(location: reading.location)
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)

                HStack {
                    if metric == .dewPoint {
                        Text("Air \(DewPointFormatters.temperature(reading.temperature))")
                    } else {
                        Text(reading.condition).lineLimit(1)
                    }
                    Text("Humidity \(DewPointFormatters.percent(reading.humidity))")
                    Spacer()
                    Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt))")
                }
                .font(.caption2)
                .foregroundStyle(secondaryTextColor)

                Spacer(minLength: 0)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: metric.widgetSymbol)
                        .foregroundStyle(comfortAccentColor(for: reading))
                    Text(metric.widgetTitle)
                        .foregroundStyle(secondaryTextColor)
                }
                .font(.caption)
                Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(dewPointValueColor(for: reading))
                HStack(spacing: 8) {
                    if metric == .dewPoint {
                        Label(DewPointFormatters.temperature(reading.temperature), systemImage: "thermometer.medium")
                    } else {
                        Text(reading.condition)
                    }
                    Label(DewPointFormatters.percent(reading.humidity), systemImage: "humidity.fill")
                }
                .font(.caption2)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                DewPointDayTimelineView(
                    reading: reading,
                    showsLabels: false,
                    trackHeight: 5,
                    markerSize: 10,
                    usesComfortColor: showsComfortColor,
                    monochromeColor: secondaryTextColor,
                    metric: metric
                )
                DewPointWidgetLocationText(location: reading.location)
                    .font(.caption2)
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(2)
                Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt))")
                    .font(.caption2)
                    .foregroundStyle(tertiaryTextColor)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
    }

    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: metric.widgetSymbol)
                .font(.title3)
            Text(entry.message ?? "Choose Location")
                .font(.caption)
                .lineLimit(3)
        }
        .foregroundStyle(secondaryTextColor)
    }

    private var primaryTextColor: Color {
        #if os(macOS)
        macTextColor(opacity: renderingMode == .vibrant ? 0.96 : 0.88)
        #else
        Color.primary
        #endif
    }

    private var secondaryTextColor: Color {
        #if os(macOS)
        macTextColor(opacity: renderingMode == .vibrant ? 0.78 : 0.62)
        #else
        Color.secondary
        #endif
    }

    private var tertiaryTextColor: Color {
        #if os(macOS)
        macTextColor(opacity: renderingMode == .vibrant ? 0.68 : 0.44)
        #else
        Color.secondary
        #endif
    }

    private func macTextColor(opacity: Double) -> Color {
        (entry.alwaysDark ? Color.white : Color.black).opacity(opacity)
    }

    private func dewPointValueColor(for reading: DewPointReading) -> Color {
        showsComfortColor ? comfortColor(for: reading) : primaryTextColor
    }

    private func comfortAccentColor(for reading: DewPointReading) -> Color {
        showsComfortColor ? comfortColor(for: reading) : secondaryTextColor
    }

    private var showsComfortColor: Bool {
        #if os(macOS)
        renderingMode == .fullColor
        #else
        renderingMode != .vibrant
        #endif
    }

    private func comfortColor(for reading: DewPointReading) -> Color {
        metric.color(forCelsius: metric.currentValue(in: reading).value)
    }
}

private struct DewPointLockScreenSquareContent: View {
    let reading: DewPointReading

    var metric: DayTimelineMetric = .dewPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(metric.widgetTitle, systemImage: metric.widgetSymbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            DewPointWidgetLocationText(location: reading.location)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            DewPointDayTimelineView(reading: reading, showsLabels: false,
                                   trackHeight: 5, markerSize: 10,
                                   usesComfortColor: false, monochromeColor: .secondary, metric: metric)
            Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct DewPointLargeWidgetContent: View {
    let reading: DewPointReading
    let primaryColor: Color
    let secondaryColor: Color
    let valueColor: Color
    let accentColor: Color
    let usesComfortColor: Bool

    var metric: DayTimelineMetric = .dewPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DewPointLargeWidgetCurrentConditions(
                reading: reading, secondaryColor: secondaryColor,
                valueColor: valueColor, accentColor: accentColor,
                usesComfortColor: usesComfortColor, metric: metric
            )
            Divider().overlay(secondaryColor.opacity(0.2))
            DewPointLargeWidgetForecast(reading: reading, textColor: primaryColor,
                                       secondaryColor: secondaryColor, usesComfortColor: usesComfortColor, metric: metric)
            Spacer(minLength: 0)
            Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt))")
                .font(.caption2)
                .foregroundStyle(secondaryColor)
                .lineLimit(1)
        }
    }
}

private struct DewPointLargeWidgetCurrentConditions: View {
    let reading: DewPointReading
    let secondaryColor: Color
    let valueColor: Color
    let accentColor: Color
    let usesComfortColor: Bool

    var metric: DayTimelineMetric = .dewPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(metric.widgetTitle, systemImage: metric.widgetSymbol)
                    .foregroundStyle(accentColor)
                Spacer(minLength: 8)
                Image(systemName: reading.symbolName)
                    .foregroundStyle(secondaryColor)
            }
            .font(.caption)
            HStack(alignment: .center) {
                Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    if metric == .dewPoint {
                        Text("Air \(DewPointFormatters.temperature(reading.temperature))")
                    } else {
                        Text(reading.condition).lineLimit(1)
                    }
                    Text("Humidity \(DewPointFormatters.percent(reading.humidity))")
                }
                .font(.caption2)
                .foregroundStyle(secondaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            DewPointWidgetLocationText(location: reading.location)
                .font(.caption)
                .foregroundStyle(secondaryColor)
                .lineLimit(1)
            DewPointDayTimelineView(reading: reading, showsLabels: false,
                                   trackHeight: 5, markerSize: 10,
                                   usesComfortColor: usesComfortColor, monochromeColor: secondaryColor, metric: metric)
        }
    }
}

private struct DewPointLargeWidgetForecast: View {
    let reading: DewPointReading
    let textColor: Color
    let secondaryColor: Color
    let usesComfortColor: Bool

    private var hasForecast: Bool {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: reading.observedAt)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
        return reading.dailyForecastPoints.contains { $0.date >= tomorrow }
    }

    var metric: DayTimelineMetric = .dewPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.widgetForecastTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(secondaryColor)
            if metric == .temperature {
                WeatherWidgetForecastRows(reading: reading, primaryColor: textColor,
                                          secondaryColor: secondaryColor, usesColor: usesComfortColor)
            } else if hasForecast {
                DewPointForecastView(reading: reading, trackHeight: 5, maximumDayCount: 7,
                                     rowSpacing: 6, usesComfortColor: usesComfortColor,
                                     monochromeColor: textColor)
            } else {
                Text("Forecast temporarily unavailable")
                    .font(.caption2)
                    .foregroundStyle(secondaryColor)
            }
        }
    }
}

#endif

#if os(iOS) || os(watchOS)
private struct DewPointAccessoryRectangularView: View {
    let reading: DewPointReading
    var usesComfortColor = false

    var metric: DayTimelineMetric = .dewPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(metric.widgetTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                    .font(.headline.monospacedDigit())
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            DewPointAccessoryTimeline(reading: reading, usesComfortColor: usesComfortColor, metric: metric)

            HStack(spacing: 6) {
                DewPointWidgetLocationText(location: reading.location)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Text(DewPointFormatters.updatedTime(reading.fetchedAt))
                    .fixedSize()
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

private struct DewPointAccessoryTimeline: View {
    let reading: DewPointReading
    let usesComfortColor: Bool
    let metric: DayTimelineMetric

    var body: some View {
        let range = metric.widgetDayRange(for: reading)
        HStack(spacing: 4) {
            if let range {
                Text("L \(DewPointFormatters.temperatureValue(Measurement(value: range.lowerBound, unit: .celsius)))°")
                    .fixedSize()
                    .accessibilityLabel("Low \(DewPointFormatters.temperature(Measurement(value: range.lowerBound, unit: .celsius)))")
            }
            if let range {
                Gauge(value: WeatherRangeScale(values: [range.lowerBound, range.upperBound])
                    .fraction(for: metric.currentValue(in: reading).value), in: 0...1) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinear)
                .tint(Gradient(colors: usesComfortColor
                    ? [metric.color(forCelsius: range.lowerBound),
                       metric.color(forCelsius: range.upperBound)]
                    : [.primary]))
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            } else {
                DewPointDayTimelineView(
                    reading: reading,
                    showsLabels: false,
                    trackHeight: 3,
                    markerSize: 7,
                    usesComfortColor: usesComfortColor,
                    monochromeColor: .primary,
                    metric: metric
                )
            }
            if let range {
                Text("H \(DewPointFormatters.temperatureValue(Measurement(value: range.upperBound, unit: .celsius)))°")
                    .fixedSize()
                    .accessibilityLabel("High \(DewPointFormatters.temperature(Measurement(value: range.upperBound, unit: .celsius)))")
            }
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
    }
}

#endif

#if os(watchOS)
struct WatchDewPointEntry: TimelineEntry {
    let date: Date
    let reading: DewPointReading?
    let message: String?
}

extension WatchDewPointEntry {
    static var previewReading: WatchDewPointEntry {
        WatchDewPointEntry(date: .now, reading: DewPointWidgetLoader.sampleReading, message: nil)
    }

    static var previewNeedsLocation: WatchDewPointEntry {
        WatchDewPointEntry(date: .now, reading: nil, message: "Choose Location")
    }
}

struct JustDewWatchEntryView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    @Environment(\.showsWidgetLabel) private var showsWidgetLabel

    let entry: WatchDewPointEntry
    let metric: DayTimelineMetric
    private let familyOverride: WidgetFamily?

    init(entry: WatchDewPointEntry, family: WidgetFamily? = nil, metric: DayTimelineMetric = .dewPoint) {
        self.entry = entry
        self.metric = metric
        familyOverride = family
    }

    var body: some View {
        Group {
            if let reading = entry.reading {
                content(for: reading)
            } else {
                unavailableContent
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var family: WidgetFamily {
        familyOverride ?? environmentFamily
    }

    @ViewBuilder
    private func content(for reading: DewPointReading) -> some View {
        switch family {
        case .accessoryInline:
            DewPointInlineWidgetText(reading: reading, metric: metric)
        case .accessoryCircular:
            circularGaugeContent(for: reading)
        case .accessoryCorner:
            if showsWidgetLabel {
                cornerGaugeContent(for: reading)
            } else {
                circularGaugeContent(for: reading)
            }
        default:
            DewPointAccessoryRectangularView(reading: reading, usesComfortColor: true, metric: metric)
        }
    }

    private func cornerGaugeContent(for reading: DewPointReading) -> some View {
        Text("\(DewPointFormatters.temperatureValue(metric.currentValue(in: reading)))\u{00B0}")
            .widgetCurvesContent()
            .widgetLabel {
                Gauge(value: metric.widgetProgress(for: reading), in: 0...1) {
                    Text(metric.widgetTitle)
                } currentValueLabel: {
                    Text("")
                } minimumValueLabel: {
                    Text("")
                } maximumValueLabel: {
                    Text("")
                }
                .tint(Gradient(colors: metric.widgetGradientColors))
            }
    }

    private func circularGaugeContent(for reading: DewPointReading) -> some View {
        Gauge(value: metric.widgetProgress(for: reading), in: 0...1) {
            Image(systemName: metric.widgetSymbol)
                .foregroundStyle(metric.color(forCelsius: metric.currentValue(in: reading).value))
                .accessibilityLabel(Text(metric.widgetTitle))
        } currentValueLabel: {
            Text(DewPointFormatters.temperatureValue(metric.currentValue(in: reading)))
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.75)
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Gradient(colors: metric.widgetGradientColors))
    }

    private var unavailableContent: some View {
        VStack(spacing: 3) {
            Image(systemName: metric.widgetSymbol)
            Text(entry.message ?? "Choose Location")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
    }
}
#endif

struct DewPointWidgetLocationText: View {
    let location: DewPointLocation

    var body: some View {
        if location.mode == .current {
            Text("\(Image(systemName: "location.fill")) \(location.widgetDisplayName)")
                .accessibilityLabel("Current Location, \(location.widgetDisplayName)")
        } else {
            Text(location.widgetDisplayName)
        }
    }
}

private struct DewPointInlineWidgetText: View {
    let reading: DewPointReading

    var metric: DayTimelineMetric = .dewPoint

    var body: some View {
        let source = reading.location.mode == .current ? Text("\(Image(systemName: "location.fill")) ") : Text("")
        if metric == .temperature {
            Text("\(source)\(Image(systemName: reading.symbolName)) \(DewPointFormatters.temperature(reading.temperature)) \(DewPointFormatters.updatedTime(reading.fetchedAt))")
        } else {
            Text("\(source)Dew \(DewPointFormatters.temperature(reading.dewPoint)) \(DewPointFormatters.updatedTime(reading.fetchedAt))")
        }
    }
}

extension DayTimelineMetric {
    var widgetTitle: LocalizedStringKey { self == .dewPoint ? "Dew Point" : "Weather" }
    var widgetForecastTitle: LocalizedStringKey { self == .dewPoint ? "Dew Point Forecast" : "Weather Forecast" }
    var widgetSymbol: String { self == .dewPoint ? "drop.degreesign.fill" : "thermometer.medium" }
    var widgetGradientColors: [Color] {
        self == .dewPoint ? DewPointComfortScale.gradientColors : [.blue, .cyan, .yellow, .orange, .red]
    }

    func widgetDayRange(for reading: DewPointReading) -> ClosedRange<Double>? {
        if self == .dewPoint { return reading.observedDayDewPointRange }
        guard let today = reading.observedDayWeather else { return nil }
        return today.lowTemperatureCelsius...today.highTemperatureCelsius
    }

    func widgetProgress(for reading: DewPointReading) -> Double {
        if self == .dewPoint { return DewPointComfortScale.progress(for: reading.dewPointCelsius) }
        let today = reading.observedDayWeather
        let low = today?.lowTemperatureCelsius ?? -10
        let high = today?.highTemperatureCelsius ?? 40
        return min(max((reading.temperatureCelsius - low) / max(high - low, 1), 0), 1)
    }
}
