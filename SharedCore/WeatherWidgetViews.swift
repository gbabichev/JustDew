#if os(iOS) || os(macOS)
import SwiftUI
import WidgetKit

/// Shared forecast styling for dew point, weather, and combined large widgets.
struct WidgetForecastRows: View {
    let reading: DewPointReading
    let primaryColor: Color
    let secondaryColor: Color
    let usesColor: Bool
    var metric: DayTimelineMetric = .temperature
    var combined = false
    var rowSpacing: CGFloat = 4
    var includesToday = false
    var dayLimit = 7
    var roomy = false
    @ScaledMetric(relativeTo: .subheadline) private var roomyDayWidth: CGFloat = 48

    var body: some View {
        let forecast = WeatherDashboardForecast(reading: reading, referenceDate: reading.observedAt)
        let days = Array(forecast.days.dropFirst(includesToday ? 0 : 1).filter { day in
            if combined { return day.hasWeatherForecast && day.hasDewPointForecast }
            return metric == .dewPoint ? day.hasDewPointForecast : day.hasWeatherForecast
        }.prefix(dayLimit))
        let dewPointScale = WeatherRangeScale(values: days.flatMap {
            [$0.lowDewPointCelsius, $0.highDewPointCelsius].compactMap { $0 }
        })
        let temperatureScale = WeatherRangeScale(values: days.flatMap {
            [$0.weather?.lowTemperatureCelsius, $0.weather?.highTemperatureCelsius].compactMap { $0 }
        })
        VStack(alignment: .leading, spacing: rowSpacing) {
            if combined && !days.isEmpty {
                HStack(spacing: 6) {
                    Text("Day").frame(width: roomy ? roomyDayWidth : 36, alignment: .leading)
                    Text("Dew Point").frame(maxWidth: .infinity)
                    Text("Weather").frame(maxWidth: .infinity)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(primaryColor)
            }
            if !days.isEmpty {
                ForEach(days) { day in
                    HStack(spacing: 6) {
                        Text(DewPointFormatters.forecastDayLabel(day.date, relativeTo: reading.observedAt,
                                                               calendar: reading.forecastCalendar))
                            .font((roomy ? Font.subheadline : .caption).weight(.medium))
                            .foregroundStyle(primaryColor)
                            .lineLimit(1)
                            .frame(width: roomy ? roomyDayWidth : (combined ? 36 : 46), alignment: .leading)
                        if !combined && metric == .temperature, let weather = day.weather {
                            Image(systemName: weather.symbolName)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(secondaryColor)
                                .frame(width: 16, height: 12)
                                .accessibilityLabel(weather.condition)
                        }
                        if combined || metric == .dewPoint {
                            WidgetForecastRange(low: day.lowDewPointCelsius, high: day.highDewPointCelsius,
                                                scale: dewPointScale, metric: .dewPoint,
                                                primaryColor: primaryColor, secondaryColor: secondaryColor, usesColor: usesColor,
                                                roomy: roomy)
                        }
                        if combined || metric == .temperature {
                            HStack(spacing: 3) {
                                if combined, let weather = day.weather {
                                    Image(systemName: weather.symbolName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 12, height: 12)
                                        .foregroundStyle(secondaryColor)
                                        .accessibilityLabel(weather.condition)
                                }
                                WidgetForecastRange(low: day.weather?.lowTemperatureCelsius,
                                                    high: day.weather?.highTemperatureCelsius,
                                                    scale: temperatureScale, metric: .temperature,
                                                    primaryColor: primaryColor, secondaryColor: secondaryColor, usesColor: usesColor,
                                                    roomy: roomy)
                            }
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
    let secondaryColor: Color
    let usesColor: Bool
    var roomy = false

    var body: some View {
        HStack(spacing: 3) {
            if let low, let high, low.isFinite, high.isFinite {
                Text(degrees(low))
                    .foregroundStyle(secondaryColor)
                    .frame(minWidth: 25, alignment: .trailing)
                GeometryReader { geometry in
                    let width = max(geometry.size.width, 1)
                    let start = scale.fraction(for: low) * width
                    let end = scale.fraction(for: high) * width
                    let barWidth = min(width, max(end - start, 4))
                    ZStack(alignment: .leading) {
                        Capsule().fill(primaryColor.opacity(0.12))
                        Capsule()
                            .fill(LinearGradient(colors: colors(low: low, high: high),
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: barWidth)
                            .offset(x: min(start, width - barWidth))
                    }
                }
                .frame(height: roomy ? 8 : 6)
                .accessibilityHidden(true)
                Text(degrees(high))
                    .fontWeight(.medium)
                    .frame(minWidth: 25, alignment: .trailing)
            } else {
                Text("—").frame(maxWidth: .infinity)
            }
        }
        .font((roomy ? Font.caption : .caption2).monospacedDigit())
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
    @Environment(\.widgetContentMargins) private var contentMargins

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
        .padding(isAccessory ? EdgeInsets() : contentMargins)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isAccessory ? .center : .topLeading)
        .modifier(WidgetRefreshPlacement(reading: entry.reading, enabled: !isAccessory, margins: contentMargins))
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
            || (family == .systemSmall && renderingMode == .vibrant)
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
    private var isLarge: Bool { family == .systemLarge || family == .systemExtraLarge }

    var body: some View {
        Group {
            if let reading = entry.reading {
                if #available(iOS 27.0, macOS 27.0, *), family == .systemExtraLargePortrait {
                    CombinedPortraitWidgetContent(reading: reading, usesColor: usesColor)
                } else if isSmall {
                    ViewThatFits(in: .vertical) {
                        CombinedSmallWidgetContent(reading: reading, usesColor: usesColor, tightSpacing: false)
                            .fixedSize(horizontal: false, vertical: true)
                        CombinedSmallWidgetContent(reading: reading, usesColor: usesColor, tightSpacing: true)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ViewThatFits(in: .vertical) {
                            CombinedStandardWidgetContent(reading: reading, usesColor: usesColor,
                                                          showsForecast: isLarge, tightSpacing: false)
                                .fixedSize(horizontal: false, vertical: true)
                            CombinedStandardWidgetContent(reading: reading, usesColor: usesColor,
                                                          showsForecast: isLarge, tightSpacing: true)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if isLarge {
                            Spacer(minLength: 0)
                            WidgetTimestamp(reading: reading)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
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

private struct CombinedStandardWidgetContent: View {
    let reading: DewPointReading
    let usesColor: Bool
    let showsForecast: Bool
    let tightSpacing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: tightSpacing ? 2 : (showsForecast ? 6 : 5)) {
            HStack(alignment: .top, spacing: 18) {
                CombinedWidgetMetric(reading: reading, metric: .dewPoint,
                                     usesColor: usesColor, tightSpacing: tightSpacing)
                CombinedWidgetMetric(reading: reading, metric: .temperature,
                                     usesColor: usesColor, tightSpacing: tightSpacing)
            }
            HStack(spacing: 8) {
                DewPointWidgetLocationText(location: reading.location)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Text("Humidity \(DewPointFormatters.percent(reading.humidity))")
                    .fixedSize()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if !showsForecast {
                WidgetTimestamp(reading: reading)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if showsForecast {
                Divider()
                WidgetForecastRows(reading: reading, primaryColor: .primary,
                                          secondaryColor: .secondary, usesColor: usesColor, combined: true,
                                          rowSpacing: tightSpacing ? 2 : 4)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct CombinedPortraitWidgetContent: View {
    let reading: DewPointReading
    let usesColor: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 18) {
                CombinedWidgetMetric(reading: reading, metric: .dewPoint, usesColor: usesColor,
                                     showsTimelineLabels: false)
                CombinedWidgetMetric(reading: reading, metric: .temperature, usesColor: usesColor,
                                     showsTimelineLabels: false)
            }
            HStack {
                DewPointWidgetLocationText(location: reading.location)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("Humidity \(DewPointFormatters.percent(reading.humidity))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Divider()
            WidgetForecastRows(reading: reading, primaryColor: .primary, secondaryColor: .secondary,
                               usesColor: usesColor, combined: true, rowSpacing: 10,
                               includesToday: true, dayLimit: 10, roomy: true)
            Spacer(minLength: 0)
            WidgetTimestamp(reading: reading)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CombinedSmallWidgetContent: View {
    let reading: DewPointReading
    let usesColor: Bool
    let tightSpacing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: tightSpacing ? 2 : 4) {
            CombinedSmallWidgetRow(reading: reading, metric: .dewPoint,
                                   usesColor: usesColor)
            CombinedSmallWidgetRow(reading: reading, metric: .temperature,
                                   usesColor: usesColor)
            HStack(spacing: 4) {
                DewPointWidgetLocationText(location: reading.location)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Color.clear.frame(width: WidgetRefreshPlacement.reservedWidth, height: 1)
                    .accessibilityHidden(true)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CombinedSmallWidgetRow: View {
    let reading: DewPointReading
    let metric: DayTimelineMetric
    let usesColor: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label {
                Text(metric.widgetTitle)
            } icon: {
                Image(systemName: metric == .temperature ? reading.symbolName : metric.widgetSymbol)
                    .foregroundStyle(usesColor ? metric.color(forCelsius: metric.currentValue(in: reading).value) : .secondary)
                    .accessibilityLabel(metric == .temperature ? Text(reading.condition) : Text(metric.widgetTitle))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            HStack(spacing: 6) {
                Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(usesColor ? metric.color(forCelsius: metric.currentValue(in: reading).value) : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)
                Spacer(minLength: 0)
                WidgetDayRangeText(reading: reading, metric: metric, stacked: true)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            DewPointDayTimelineView(
                reading: reading, showsLabels: false,
                trackHeight: 3, markerSize: 6,
                usesComfortColor: usesColor, monochromeColor: .secondary, metric: metric
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                Text("Dew \(DewPointFormatters.temperature(reading.dewPoint)) · \(Image(systemName: reading.symbolName)) \(DewPointFormatters.temperature(reading.temperature))")
            case .accessoryCircular:
                VStack(spacing: 2) {
                    CombinedAccessoryValue(reading: reading, metric: .dewPoint)
                    CombinedAccessoryValue(reading: reading, metric: .temperature)
                }
            case .systemSmall:
                VStack(alignment: .leading, spacing: 12) {
                    CombinedLockScreenSquareMetric(reading: reading, metric: .dewPoint)
                    CombinedLockScreenSquareMetric(reading: reading, metric: .temperature)
                }
            default:
                ViewThatFits(in: .vertical) {
                    CombinedAccessoryRectangularContent(reading: reading, compact: false)
                        .fixedSize(horizontal: false, vertical: true)
                    CombinedAccessoryRectangularContent(reading: reading, compact: true)
                        .fixedSize(horizontal: false, vertical: true)
                }
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

private struct CombinedLockScreenSquareMetric: View {
    let reading: DewPointReading
    let metric: DayTimelineMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(metric.widgetTitle,
                  systemImage: metric == .temperature ? reading.symbolName : metric.widgetSymbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                WidgetDayRangeText(reading: reading, metric: metric)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CombinedAccessoryRectangularContent: View {
    let reading: DewPointReading
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 10) {
                CombinedAccessoryMetric(reading: reading, metric: .dewPoint, compact: compact)
                CombinedAccessoryMetric(reading: reading, metric: .temperature, compact: compact)
            }
        }
    }
}

private struct CombinedAccessoryValue: View {
    let reading: DewPointReading
    let metric: DayTimelineMetric

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                Image(systemName: metric == .temperature ? reading.symbolName : metric.widgetSymbol)
                    .frame(width: 12)
                Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.system(size: 11, weight: .semibold))
            WidgetDayRangeText(reading: reading, metric: metric)
                .font(.system(size: 7))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(metric.widgetTitle))
    }
}

private struct CombinedAccessoryMetric: View {
    let reading: DewPointReading
    let metric: DayTimelineMetric
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                if metric == .temperature {
                    Image(systemName: reading.symbolName)
                        .accessibilityLabel(reading.condition)
                }
                Text(metric.widgetTitle)
            }
            .font(.system(size: compact ? 8 : 9))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                .font(.system(size: compact ? 16 : 18, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let range = metric.widgetDayRange(for: reading) {
                Text("L \(DewPointFormatters.temperatureValue(Measurement(value: range.lowerBound, unit: .celsius)))°  H \(DewPointFormatters.temperatureValue(Measurement(value: range.upperBound, unit: .celsius)))°")
                    .font(.system(size: compact ? 8 : 9).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(metric.widgetTitle))
        .accessibilityValue(accessibilitySummary)
    }

    private var accessibilitySummary: Text {
        let current = DewPointFormatters.temperature(metric.currentValue(in: reading))
        guard let range = metric.widgetDayRange(for: reading) else { return Text(current) }
        let low = DewPointFormatters.temperature(Measurement(value: range.lowerBound, unit: .celsius))
        let high = DewPointFormatters.temperature(Measurement(value: range.upperBound, unit: .celsius))
        return Text("Now \(current). Low \(low), high \(high).")
    }
}

#endif

private struct CombinedWidgetMetric: View {
    let reading: DewPointReading
    let metric: DayTimelineMetric
    let usesColor: Bool
    var showsTimelineLabels = false
    var tightSpacing = false

    var body: some View {
        VStack(alignment: .leading, spacing: tightSpacing ? 3 : 5) {
            HStack(spacing: 6) {
                Image(systemName: metric.widgetSymbol)
                    .foregroundStyle(usesColor ? metric.color(forCelsius: metric.currentValue(in: reading).value) : .secondary)
                Text(metric.widgetTitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if metric == .temperature {
                    Spacer(minLength: 0)
                    WidgetConditionSymbol(symbolName: reading.symbolName, condition: reading.condition,
                                          size: 14)
                }
            }
            .font(.caption)
            HStack(alignment: .center, spacing: 4) {
                Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(usesColor ? metric.color(forCelsius: metric.currentValue(in: reading).value) : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .accessibilityLabel(Text(metric.widgetTitle))
                    .accessibilityValue(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                Spacer(minLength: 0)
                WidgetDayRangeText(reading: reading, metric: metric, stacked: true)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            DewPointDayTimelineView(reading: reading, showsLabels: showsTimelineLabels,
                                   trackHeight: 7, markerSize: 14,
                                   usesComfortColor: usesColor, monochromeColor: .secondary, metric: metric)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }
}
#endif
