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
        return await entry(for: configuration, in: context)
    }

    func timeline(for configuration: Options, in context: Context) async -> Timeline<DewPointWidgetEntry> {
        Timeline(entries: [await entry(for: configuration, in: context)],
                 policy: .after(Date().addingTimeInterval(DewPointConfiguration.refreshInterval)))
    }

    private func entry(for configuration: Options, in context: Context) async -> DewPointWidgetEntry {
        let usesCurrentLocation: Bool
        switch context.family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            usesCurrentLocation = true
        default:
            usesCurrentLocation = false
        }
        // Accessory widgets follow the device, regardless of saved Home Screen settings.
        let id = usesCurrentLocation ? "current" : (configuration.location?.id ?? "current")
        let alwaysDark = !usesCurrentLocation && configuration.alwaysDark
        do {
            let reading = try await DewPointWidgetLoader.loadReading(locationID: id)
            return DewPointWidgetEntry(date: .now, reading: reading, message: nil, alwaysDark: alwaysDark)
        } catch {
            // Without location permission, show the alert instead of a reading for a place that may be wrong.
            if id == "current", let error = error as? DewPointError, error.isLocationPermissionProblem {
                return DewPointWidgetEntry(date: .now, reading: nil, message: error.dewPointDisplayMessage,
                                           alwaysDark: alwaysDark)
            }
            return DewPointWidgetEntry(date: .now, reading: DewPointWidgetLoader.cachedReading(locationID: id),
                                       message: error.dewPointDisplayMessage, alwaysDark: alwaysDark)
        }
    }
}

enum WeatherWidgetFamilies {
    static var home: [WidgetFamily] {
        if #available(iOS 27.0, macOS 27.0, *) {
            [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .systemExtraLargePortrait]
        } else {
            [.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge]
        }
    }
    static var all: [WidgetFamily] {
        #if os(macOS)
        home
        #else
        home + [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        #endif
    }

    // The rectangular Lock Screen size is reserved for the combined readings.
    static var singleMetric: [WidgetFamily] {
        #if os(macOS)
        home
        #else
        all.filter { $0 != .accessoryRectangular }
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
        .description("Weather for your current location.")
        .supportedFamilies(WeatherWidgetFamilies.singleMetric)
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
        .description("Dew point and weather for your current location.")
        .supportedFamilies(WeatherWidgetFamilies.all)
        .contentMarginsDisabled()
    }
}
