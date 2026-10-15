import AppIntents
import SwiftUI
import WidgetKit

struct ConfiguredDewPointProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DewPointWidgetEntry {
        .previewReading
    }

    func snapshot(for configuration: DewPointWidgetIntent, in context: Context) async -> DewPointWidgetEntry {
        if context.isPreview {
            var entry = DewPointWidgetEntry.previewReading
            entry.alwaysDark = configuration.alwaysDark
            return entry
        }
        return await entry(for: configuration)
    }

    func timeline(for configuration: DewPointWidgetIntent, in context: Context) async -> Timeline<DewPointWidgetEntry> {
        Timeline(entries: [await entry(for: configuration)],
                 policy: .after(Date().addingTimeInterval(DewPointConfiguration.refreshInterval)))
    }

    private func entry(for configuration: DewPointWidgetIntent) async -> DewPointWidgetEntry {
        let id = configuration.location?.id ?? "current"
        do {
            let reading = try await DewPointWidgetLoader.loadReading(locationID: id)
            return DewPointWidgetEntry(date: .now, reading: reading, message: nil, alwaysDark: configuration.alwaysDark)
        } catch {
            return DewPointWidgetEntry(date: .now, reading: DewPointWidgetLoader.cachedReading(locationID: id),
                                       message: error.dewPointDisplayMessage, alwaysDark: configuration.alwaysDark)
        }
    }
}

struct DarkDewPointProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DewPointWidgetEntry {
        DewPointWidgetEntry(date: .now, reading: DewPointWidgetLoader.sampleReading, message: nil, alwaysDark: true)
    }

    func snapshot(for configuration: DarkDewPointWidgetIntent, in context: Context) async -> DewPointWidgetEntry {
        if context.isPreview { return placeholder(in: context) }
        return await entry(for: configuration, in: context)
    }

    func timeline(for configuration: DarkDewPointWidgetIntent, in context: Context) async -> Timeline<DewPointWidgetEntry> {
        Timeline(entries: [await entry(for: configuration, in: context)],
                 policy: .after(Date().addingTimeInterval(DewPointConfiguration.refreshInterval)))
    }

    private func entry(for configuration: DarkDewPointWidgetIntent, in context: Context) async -> DewPointWidgetEntry {
        let options = DewPointWidgetIntent()
        options.location = configuration.location
        options.alwaysDark = true
        return await ConfiguredDewPointProvider().snapshot(for: options, in: context)
    }
}

struct SavedLocationDewPointWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "JustDewSavedLocationWidget", intent: DewPointWidgetIntent.self,
                               provider: ConfiguredDewPointProvider()) { entry in
            JustDewWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Dew Point · Location")
        .description("Choose Current Location or a saved city, with an optional dark appearance.")
        #if os(macOS)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        #else
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        #endif
        .contentMarginsDisabled()
    }
}

struct AlwaysDarkDewPointWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "JustDewAlwaysDarkWidget", provider: DewPointWidgetProvider()) { entry in
            JustDewWidgetEntryView(entry: DewPointWidgetEntry(date: entry.date, reading: entry.reading,
                                                            message: entry.message, alwaysDark: true))
        }
        .configurationDisplayName("Dew Point · Always Dark")
        .description("An always dark dew point widget that follows your current location.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct AlwaysDarkLocationDewPointWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "JustDewAlwaysDarkLocationWidget", intent: DarkDewPointWidgetIntent.self,
                               provider: DarkDewPointProvider()) { entry in
            JustDewWidgetEntryView(entry: DewPointWidgetEntry(date: entry.date, reading: entry.reading,
                                                            message: entry.message, alwaysDark: true))
        }
        .configurationDisplayName("Dew Point · Location · Always Dark")
        .description("Choose a saved city in Edit Widget to keep its dew point visible in an always dark appearance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
