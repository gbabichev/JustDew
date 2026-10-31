import AppIntents
import SwiftUI
import WidgetKit

struct WeatherLocationProvider<Options: WeatherLocationWidgetOptions>: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DewPointWidgetEntry {
        DewPointWidgetEntry(date: .now, reading: DewPointWidgetLoader.sampleReading, message: nil, alwaysDark: false)
    }

    func snapshot(for configuration: Options, in context: Context) async -> DewPointWidgetEntry {
        if context.isPreview {
            return DewPointWidgetEntry(date: .now, reading: DewPointWidgetLoader.sampleReading,
                                       message: nil, alwaysDark: configuration.alwaysDark)
        }
        return await entry(for: configuration)
    }

    func timeline(for configuration: Options, in context: Context) async -> Timeline<DewPointWidgetEntry> {
        Timeline(entries: [await entry(for: configuration)],
                 policy: .after(Date().addingTimeInterval(DewPointConfiguration.refreshInterval)))
    }

    private func entry(for configuration: Options) async -> DewPointWidgetEntry {
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

enum WeatherWidgetFamilies {
    static let home: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
    static var all: [WidgetFamily] {
        #if os(macOS)
        home
        #else
        home + [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        #endif
    }
}

struct SavedLocationWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "JustDewSavedLocationWeatherWidget", intent: WeatherWidgetIntent.self,
                               provider: WeatherLocationProvider<WeatherWidgetIntent>()) { entry in
            JustDewWidgetEntryView(entry: entry, metric: .temperature)
        }
        .configurationDisplayName("Weather")
        .description("Choose Current Location or a saved city, and optionally use an always dark appearance.")
        .supportedFamilies(WeatherWidgetFamilies.all)
        .contentMarginsDisabled()
    }
}

struct SavedLocationCombinedWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "JustDewSavedLocationCombinedWeatherWidget", intent: CombinedWeatherWidgetIntent.self,
                               provider: WeatherLocationProvider<CombinedWeatherWidgetIntent>()) { entry in
            CombinedWeatherWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Dew Point + Weather")
        .description("Choose Current Location or a saved city, and optionally use an always dark appearance.")
        .supportedFamilies(WeatherWidgetFamilies.all)
        .contentMarginsDisabled()
    }
}
