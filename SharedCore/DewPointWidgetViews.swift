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

    let entry: DewPointWidgetEntry
    private let familyOverride: WidgetFamily?

    init(entry: DewPointWidgetEntry, family: WidgetFamily? = nil) {
        self.entry = entry
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
        switch family {
        #if os(iOS)
        case .systemSmall:
            EdgeInsets(top: 21, leading: 20, bottom: 14, trailing: 20)
        case .systemMedium, .systemLarge, .systemExtraLarge:
            EdgeInsets(top: 25, leading: 20, bottom: 16, trailing: 20)
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

    @ViewBuilder
    private func content(for reading: DewPointReading) -> some View {
        switch family {
        #if os(iOS)
        case .accessoryInline:
            Text("Dew \(DewPointFormatters.temperature(reading.dewPoint)) \(DewPointFormatters.updatedTime(reading.fetchedAt))")
                .foregroundStyle(primaryTextColor)
        case .accessoryCircular:
            VStack(spacing: 2) {
                Image(systemName: "drop.degreesign.fill")
                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.caption.bold())
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(primaryTextColor)
        case .accessoryRectangular:
            DewPointLockScreenRectangularView(reading: reading)
        #endif
        case .systemMedium, .systemLarge, .systemExtraLarge:
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "drop.degreesign.fill")
                            .foregroundStyle(comfortAccentColor(for: reading))
                        Text("Dew Point")
                            .foregroundStyle(secondaryTextColor)
                    }
                    Spacer()
                    Image(systemName: reading.symbolName)
                        .foregroundStyle(secondaryTextColor)
                }
                .font(.caption)

                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(dewPointValueColor(for: reading))

                DewPointDayTimelineView(
                    reading: reading,
                    showsLabels: false,
                    trackHeight: 7,
                    markerSize: 14,
                    usesComfortColor: showsComfortColor,
                    monochromeColor: secondaryTextColor
                )

                Text(reading.location.widgetDisplayName)
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)

                HStack {
                    Text("Air \(DewPointFormatters.temperature(reading.temperature))")
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
                    Image(systemName: "drop.degreesign.fill")
                        .foregroundStyle(comfortAccentColor(for: reading))
                    Text("Dew Point")
                        .foregroundStyle(secondaryTextColor)
                }
                .font(.caption)
                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(dewPointValueColor(for: reading))
                HStack(spacing: 8) {
                    Label(DewPointFormatters.temperature(reading.temperature), systemImage: "thermometer.medium")
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
                    monochromeColor: secondaryTextColor
                )
                Text(reading.location.widgetDisplayName)
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
            Image(systemName: "drop.degreesign")
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
        true
        #endif
    }

    private func comfortColor(for reading: DewPointReading) -> Color {
        DewPointComfortScale.color(for: reading.dewPointCelsius)
    }
}
#if os(iOS)
private struct DewPointLockScreenRectangularView: View {
    let reading: DewPointReading

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Dew Point")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.headline.monospacedDigit())
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            DewPointDayTimelineView(
                reading: reading,
                showsLabels: false,
                trackHeight: 3,
                markerSize: 7,
                usesComfortColor: false,
                monochromeColor: .primary
            )

            HStack(spacing: 6) {
                Text(reading.location.widgetDisplayName)
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
#endif

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
    private let familyOverride: WidgetFamily?

    init(entry: WatchDewPointEntry, family: WidgetFamily? = nil) {
        self.entry = entry
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
            Text("Dew \(DewPointFormatters.temperature(reading.dewPoint)) \(DewPointFormatters.updatedTime(reading.fetchedAt))")
        case .accessoryCircular:
            circularGaugeContent(for: reading)
        case .accessoryCorner:
            if showsWidgetLabel {
                cornerGaugeContent(for: reading)
            } else {
                circularGaugeContent(for: reading)
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text("Dew Point")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.headline.monospacedDigit())
                DewPointDayTimelineView(
                    reading: reading,
                    showsLabels: false,
                    trackHeight: 4,
                    markerSize: 8
                )
                Text(reading.location.widgetDisplayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(DewPointFormatters.updatedTime(reading.fetchedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func cornerGaugeContent(for reading: DewPointReading) -> some View {
        Text("\(DewPointFormatters.temperatureValue(reading.dewPoint))\u{00B0}")
            .widgetCurvesContent()
            .widgetLabel {
                Gauge(value: DewPointComfortScale.progress(for: reading.dewPointCelsius), in: 0...1) {
                    Text("Dew Point")
                } currentValueLabel: {
                    Text("")
                } minimumValueLabel: {
                    Text("")
                } maximumValueLabel: {
                    Text("")
                }
                .tint(Gradient(colors: DewPointComfortScale.gradientColors))
            }
    }

    private func circularGaugeContent(for reading: DewPointReading) -> some View {
        Gauge(value: DewPointComfortScale.progress(for: reading.dewPointCelsius), in: 0...1) {
            Image(systemName: "drop.degreesign.fill")
                .foregroundStyle(DewPointComfortScale.color(for: reading.dewPointCelsius))
        } currentValueLabel: {
            Text(DewPointFormatters.temperatureValue(reading.dewPoint))
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.75)
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Gradient(colors: DewPointComfortScale.gradientColors))
    }

    private var unavailableContent: some View {
        VStack(spacing: 3) {
            Image(systemName: "drop.degreesign")
            Text(entry.message ?? "Choose Location")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
    }
}
#endif
