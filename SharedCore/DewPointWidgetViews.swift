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

struct JustDewWidgetEntryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var environmentFamily
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.widgetContentMargins) private var contentMargins

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
        if #available(iOS 27.0, macOS 27.0, *), family == .systemExtraLargePortrait {
            return contentMargins
        }
        // Keep accessories edge-to-edge; use WidgetKit's context-specific margins at home.
        return switch family {
        case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
            isLockScreenSquare ? EdgeInsets() : contentMargins
        default:
            EdgeInsets()
        }
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
        if #available(iOS 27.0, macOS 27.0, *), family == .systemExtraLargePortrait {
            DewPointPortraitWidgetContent(reading: reading, primaryColor: primaryTextColor,
                                          secondaryColor: secondaryTextColor, valueColor: dewPointValueColor(for: reading),
                                          accentColor: comfortAccentColor(for: reading),
                                          usesComfortColor: showsComfortColor, metric: metric)
        } else {
            existingContent(for: reading)
        }
    }

    @ViewBuilder
    private func existingContent(for reading: DewPointReading) -> some View {
        switch family {
        #if os(iOS)
        case .accessoryInline:
            DewPointInlineWidgetText(reading: reading, metric: metric)
                .foregroundStyle(primaryTextColor)
        case .accessoryCircular:
            VStack(spacing: 1) {
                if metric == .dewPoint {
                    DewPointCircularWidgetIcon(isCurrentLocation: reading.location.mode == .current,
                                               size: metric.widgetDayRange(for: reading) == nil ? 24 : 20)
                } else {
                    Image(systemName: reading.symbolName)
                        .accessibilityLabel(reading.condition)
                }
                Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                WidgetDayRangeText(reading: reading, metric: metric)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
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
            ViewThatFits(in: .vertical) {
                DewPointMediumWidgetContent(
                    reading: reading, metric: metric, tightSpacing: false,
                    accentColor: comfortAccentColor(for: reading),
                    valueColor: dewPointValueColor(for: reading),
                    secondaryTextColor: secondaryTextColor, usesComfortColor: showsComfortColor
                )
                .fixedSize(horizontal: false, vertical: true)
                DewPointMediumWidgetContent(
                    reading: reading, metric: metric, tightSpacing: true,
                    accentColor: comfortAccentColor(for: reading),
                    valueColor: dewPointValueColor(for: reading),
                    secondaryTextColor: secondaryTextColor, usesComfortColor: showsComfortColor
                )
                .fixedSize(horizontal: false, vertical: true)
            }
        default:
            ViewThatFits(in: .vertical) {
                DewPointSmallWidgetContent(
                    reading: reading, metric: metric, tightSpacing: false,
                    accentColor: comfortAccentColor(for: reading),
                    valueColor: dewPointValueColor(for: reading),
                    secondaryTextColor: secondaryTextColor, tertiaryTextColor: tertiaryTextColor,
                    usesComfortColor: showsComfortColor
                )
                .fixedSize(horizontal: false, vertical: true)
                DewPointSmallWidgetContent(
                    reading: reading, metric: metric, tightSpacing: true,
                    accentColor: comfortAccentColor(for: reading),
                    valueColor: dewPointValueColor(for: reading),
                    secondaryTextColor: secondaryTextColor, tertiaryTextColor: tertiaryTextColor,
                    usesComfortColor: showsComfortColor
                )
                .fixedSize(horizontal: false, vertical: true)
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

#if os(iOS)
private struct DewPointCircularWidgetIcon: View {
    let isCurrentLocation: Bool
    let size: CGFloat

    var body: some View {
        Image(systemName: "drop.degreesign.fill")
            .font(.system(size: size, weight: .medium))
            .frame(width: size + 6, height: size + 3)
            .overlay(alignment: .topTrailing) {
                if isCurrentLocation {
                    Image(systemName: "location.fill")
                        .font(.system(size: 8, weight: .bold))
                        .offset(x: 5, y: -1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isCurrentLocation ? Text("Dew Point, Current Location") : Text("Dew Point"))
    }
}
#endif

private struct DewPointMediumWidgetContent: View {
    let reading: DewPointReading
    let metric: DayTimelineMetric
    let tightSpacing: Bool
    let accentColor: Color
    let valueColor: Color
    let secondaryTextColor: Color
    let usesComfortColor: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: tightSpacing ? 2 : 5) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: metric.widgetSymbol)
                        .foregroundStyle(accentColor)
                    Text(metric.widgetTitle)
                        .foregroundStyle(secondaryTextColor)
                }
                Spacer()
                if metric == .dewPoint {
                    Image(systemName: reading.symbolName)
                        .foregroundStyle(secondaryTextColor)
                        .accessibilityLabel(reading.condition)
                }
            }
            .font(.caption)

            HStack(spacing: 8) {
                Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                if metric == .temperature {
                    WidgetConditionSymbol(symbolName: reading.symbolName, condition: reading.condition,
                                          size: 20)
                }
            }

            DewPointDayTimelineView(
                reading: reading,
                showsLabels: false,
                trackHeight: 7,
                markerSize: 14,
                usesComfortColor: usesComfortColor,
                monochromeColor: secondaryTextColor,
                metric: metric
            )

            HStack(spacing: 8) {
                DewPointWidgetLocationText(location: reading.location)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                WidgetDayRangeText(reading: reading, metric: metric)
                    .fixedSize()
            }
            .font(.caption)
            .foregroundStyle(secondaryTextColor)

            HStack {
                if metric == .dewPoint {
                    Text("Air \(DewPointFormatters.temperature(reading.temperature))")
                }
                Text("Humidity \(DewPointFormatters.percent(reading.humidity))")
                Spacer()
                WidgetUpdateTime(date: reading.fetchedAt, timeZone: reading.forecastCalendar.timeZone)
            }
            .font(.caption2)
            .foregroundStyle(secondaryTextColor)
        }
    }
}

struct WidgetConditionSymbol: View {
    let symbolName: String
    let condition: String
    let size: CGFloat

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size))
            .foregroundStyle(.secondary)
            .accessibilityLabel(condition)
    }
}

struct WidgetUpdateTime: View {
    let date: Date
    let timeZone: TimeZone

    var body: some View {
        let time = DewPointFormatters.updatedTime(date, timeZone: timeZone)
        Text("\(Image(systemName: "clock")) \(time)")
            .lineLimit(1)
            .accessibilityLabel(Text("Updated \(time)"))
    }
}

struct WidgetDayRangeText: View {
    let reading: DewPointReading
    let metric: DayTimelineMetric
    var stacked = false

    var body: some View {
        if let range = metric.widgetDayRange(for: reading) {
            let low = DewPointFormatters.temperatureValue(Measurement(value: range.lowerBound, unit: .celsius))
            let high = DewPointFormatters.temperatureValue(Measurement(value: range.upperBound, unit: .celsius))
            let label = stacked ? Text("L \(low)°\nH \(high)°") : Text("L \(low)°  H \(high)°")
            label
                .monospacedDigit()
                .lineLimit(stacked ? 2 : 1)
                .minimumScaleFactor(0.8)
                .accessibilityLabel(Text("Today's \(Text(metric.widgetTitle)) forecast"))
                .accessibilityValue(Text("Low \(DewPointFormatters.temperature(Measurement(value: range.lowerBound, unit: .celsius))), high \(DewPointFormatters.temperature(Measurement(value: range.upperBound, unit: .celsius)))"))
        }
    }
}

private struct DewPointSmallWidgetContent: View {
    let reading: DewPointReading
    let metric: DayTimelineMetric
    let tightSpacing: Bool
    let accentColor: Color
    let valueColor: Color
    let secondaryTextColor: Color
    let tertiaryTextColor: Color
    let usesComfortColor: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: tightSpacing ? 2 : 6) {
            HStack(spacing: 5) {
                Image(systemName: metric.widgetSymbol)
                    .foregroundStyle(accentColor)
                Text(metric.widgetTitle)
                    .foregroundStyle(secondaryTextColor)
            }
            .font(.caption)
            HStack(spacing: 8) {
                Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                    .font(.system(tightSpacing ? .title : .largeTitle, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                if metric == .temperature {
                    WidgetConditionSymbol(symbolName: reading.symbolName, condition: reading.condition,
                                          size: 20)
                }
            }
            if metric.widgetDayRange(for: reading) != nil {
                WidgetDayRangeText(reading: reading, metric: metric)
                    .font(.caption2)
                    .foregroundStyle(secondaryTextColor)
            } else {
                HStack(spacing: 8) {
                    if metric == .dewPoint {
                        Label(DewPointFormatters.temperature(reading.temperature), systemImage: "thermometer.medium")
                    }
                    Label(DewPointFormatters.percent(reading.humidity), systemImage: "humidity.fill")
                }
                .font(.caption2)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
            DewPointDayTimelineView(
                reading: reading,
                showsLabels: false,
                trackHeight: 5,
                markerSize: 10,
                usesComfortColor: usesComfortColor,
                monochromeColor: secondaryTextColor,
                metric: metric
            )
            DewPointWidgetLocationText(location: reading.location)
                .font(.caption2)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
            WidgetUpdateTime(date: reading.fetchedAt, timeZone: reading.forecastCalendar.timeZone)
                .font(.caption2)
                .foregroundStyle(tertiaryTextColor)
                .lineLimit(1)
        }
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
            WidgetUpdateTime(date: reading.fetchedAt, timeZone: reading.forecastCalendar.timeZone)
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
        VStack(alignment: .leading, spacing: 6) {
            DewPointLargeWidgetCurrentConditions(
                reading: reading, secondaryColor: secondaryColor,
                valueColor: valueColor, accentColor: accentColor,
                usesComfortColor: usesComfortColor, metric: metric
            )
            Divider().overlay(secondaryColor.opacity(0.2))
            DewPointLargeWidgetForecast(reading: reading, textColor: primaryColor,
                                       secondaryColor: secondaryColor, usesComfortColor: usesComfortColor, metric: metric)
            Spacer(minLength: 0)
            WidgetUpdateTime(date: reading.fetchedAt, timeZone: reading.forecastCalendar.timeZone)
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
    var showsTimelineLabels = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(metric.widgetTitle, systemImage: metric.widgetSymbol)
                    .foregroundStyle(accentColor)
                Spacer(minLength: 8)
                if metric == .dewPoint {
                    Image(systemName: reading.symbolName)
                        .foregroundStyle(secondaryColor)
                        .accessibilityLabel(reading.condition)
                }
            }
            .font(.caption)
            HStack(alignment: .center) {
                Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if metric == .temperature {
                    WidgetConditionSymbol(symbolName: reading.symbolName, condition: reading.condition, size: 22)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    if metric == .dewPoint {
                        Text("Air \(DewPointFormatters.temperature(reading.temperature))")
                    }
                    Text("Humidity \(DewPointFormatters.percent(reading.humidity))")
                }
                .font(.caption2)
                .foregroundStyle(secondaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            HStack(spacing: 8) {
                DewPointWidgetLocationText(location: reading.location)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                WidgetDayRangeText(reading: reading, metric: metric)
                    .fixedSize()
            }
            .font(.caption)
            .foregroundStyle(secondaryColor)
            DewPointDayTimelineView(reading: reading, showsLabels: showsTimelineLabels,
                                   trackHeight: 5, markerSize: 10,
                                   usesComfortColor: usesComfortColor, monochromeColor: secondaryColor, metric: metric)
        }
    }
}

private struct DewPointPortraitWidgetContent: View {
    let reading: DewPointReading
    let primaryColor: Color
    let secondaryColor: Color
    let valueColor: Color
    let accentColor: Color
    let usesComfortColor: Bool
    let metric: DayTimelineMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DewPointLargeWidgetCurrentConditions(reading: reading, secondaryColor: secondaryColor,
                                                 valueColor: valueColor, accentColor: accentColor,
                                                 usesComfortColor: usesComfortColor, metric: metric,
                                                 showsTimelineLabels: false)
            Divider()
            Text(metric == .dewPoint ? "10-Day Dew Point" : "10-Day Weather")
                .font(.headline)
                .foregroundStyle(primaryColor)
            WidgetForecastRows(reading: reading, primaryColor: primaryColor,
                               secondaryColor: secondaryColor, usesColor: usesComfortColor,
                               metric: metric, rowSpacing: 10, includesToday: true, dayLimit: 10, roomy: true)
            Spacer(minLength: 0)
            WidgetUpdateTime(date: reading.fetchedAt, timeZone: reading.forecastCalendar.timeZone)
                .font(.caption2)
                .foregroundStyle(secondaryColor)
        }
    }
}

private struct DewPointLargeWidgetForecast: View {
    let reading: DewPointReading
    let textColor: Color
    let secondaryColor: Color
    let usesComfortColor: Bool

    var metric: DayTimelineMetric = .dewPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric.widgetForecastTitle)
                .font(.headline)
                .foregroundStyle(textColor)
            WidgetForecastRows(reading: reading, primaryColor: textColor,
                               secondaryColor: secondaryColor, usesColor: usesComfortColor,
                               metric: metric)
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
