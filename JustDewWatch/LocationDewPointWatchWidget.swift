import AppIntents
import SwiftUI
import WidgetKit

struct LocationDewPointWatchProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WatchDewPointEntry {
        .previewReading
    }

    func snapshot(for configuration: WatchLocationDewPointIntent, in context: Context) async -> WatchDewPointEntry {
        if context.isPreview { return .previewReading }
        return await entry(for: configuration)
    }

    func timeline(for configuration: WatchLocationDewPointIntent, in context: Context) async -> Timeline<WatchDewPointEntry> {
        Timeline(entries: [await entry(for: configuration)],
                 policy: .after(Date().addingTimeInterval(DewPointConfiguration.refreshInterval)))
    }

    func recommendations() -> [AppIntentRecommendation<WatchLocationDewPointIntent>] {
        // Let people configure each complication's location using the Watch picker.
        []
    }

    private func entry(for configuration: WatchLocationDewPointIntent) async -> WatchDewPointEntry {
        let id = configuration.location?.id ?? "current"
        do {
            let reading = try await DewPointWidgetLoader.loadReading(locationID: id)
            return WatchDewPointEntry(date: .now, reading: reading, message: nil)
        } catch {
            return WatchDewPointEntry(date: .now, reading: DewPointWidgetLoader.cachedReading(locationID: id),
                                      message: error.dewPointDisplayMessage)
        }
    }
}

struct LocationDewPointWatchWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "JustDewWatchLocationWidget", intent: WatchLocationDewPointIntent.self,
                               provider: LocationDewPointWatchProvider()) { entry in
            JustDewWatchEntryView(entry: entry)
        }
        .configurationDisplayName("Dew Point · Saved Location")
        .description("Keep the dew point for a saved city on your watch face or in the Smart Stack.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
