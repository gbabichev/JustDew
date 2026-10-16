import AppIntents
import SwiftUI
import WidgetKit

struct LocationWeatherWatchProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WatchDewPointEntry { .previewReading }

    func snapshot(for configuration: WatchLocationWeatherIntent, in context: Context) async -> WatchDewPointEntry {
        if context.isPreview { return .previewReading }
        return await entry(for: configuration)
    }

    func timeline(for configuration: WatchLocationWeatherIntent, in context: Context) async -> Timeline<WatchDewPointEntry> {
        Timeline(entries: [await entry(for: configuration)],
                 policy: .after(Date().addingTimeInterval(DewPointConfiguration.refreshInterval)))
    }

    func recommendations() -> [AppIntentRecommendation<WatchLocationWeatherIntent>] { [] }

    private func entry(for configuration: WatchLocationWeatherIntent) async -> WatchDewPointEntry {
        let id = configuration.location?.id ?? "current"
        do {
            return WatchDewPointEntry(date: .now, reading: try await DewPointWidgetLoader.loadReading(locationID: id), message: nil)
        } catch {
            return WatchDewPointEntry(date: .now, reading: DewPointWidgetLoader.cachedReading(locationID: id),
                                      message: error.dewPointDisplayMessage)
        }
    }
}

struct WeatherWatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "JustDewWatchWeatherWidget", provider: WatchDewPointProvider()) { entry in
            JustDewWatchEntryView(entry: entry, metric: .temperature)
        }
        .configurationDisplayName("Weather · Current Location")
        .description("Shows the weather at your current location on your watch face and in the Smart Stack.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct LocationWeatherWatchWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "JustDewWatchLocationWeatherWidget", intent: WatchLocationWeatherIntent.self,
                               provider: LocationWeatherWatchProvider()) { entry in
            JustDewWatchEntryView(entry: entry, metric: .temperature)
        }
        .configurationDisplayName("Weather · Saved Location")
        .description("Keep a saved city's weather on your watch face or in the Smart Stack.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
