import SwiftUI
import WidgetKit

#if os(iOS) || os(macOS)
struct DewPointWidgetEntry: TimelineEntry {
    let date: Date
    let reading: DewPointReading?
    let message: String?
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
    @Environment(\.widgetFamily) private var environmentFamily

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
        #if os(macOS)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        #endif
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var family: WidgetFamily {
        familyOverride ?? environmentFamily
    }

    private var contentAlignment: Alignment {
        switch family {
        #if os(iOS)
        case .accessoryCircular:
            .center
        #endif
        case .accessoryInline:
            .center
        default:
            .topLeading
        }
    }

    @ViewBuilder
    private func content(for reading: DewPointReading) -> some View {
        switch family {
        #if os(iOS)
        case .accessoryInline:
            Text("Dew \(DewPointFormatters.temperature(reading.dewPoint)) \(DewPointFormatters.updatedTime(reading.fetchedAt))")
        case .accessoryCircular:
            VStack(spacing: 2) {
                Image(systemName: "drop.degreesign.fill")
                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.caption.bold())
                    .minimumScaleFactor(0.7)
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Dew Point")
                    .font(.caption2)
                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.headline.monospacedDigit())
                Text(reading.location.widgetDisplayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(DewPointFormatters.updatedTime(reading.fetchedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        #endif
        case .systemMedium, .systemLarge, .systemExtraLarge:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Dew Point", systemImage: "drop.degreesign.fill")
                    Spacer()
                    Image(systemName: reading.symbolName)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Text(reading.location.widgetDisplayName)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack {
                    Text("Air \(DewPointFormatters.temperature(reading.temperature))")
                    Text("Humidity \(DewPointFormatters.percent(reading.humidity))")
                    Spacer()
                    Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Label("Dew Point", systemImage: "drop.degreesign.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(reading.location.widgetDisplayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
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
        case .accessoryCircular, .accessoryCorner:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "drop.degreesign.fill")
                    Text(DewPointFormatters.temperature(reading.dewPoint))
                        .font(.caption2.bold())
                        .minimumScaleFactor(0.7)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text("Dew Point")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.headline.monospacedDigit())
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
