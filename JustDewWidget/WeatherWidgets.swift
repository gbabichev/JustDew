import AppIntents
import SwiftUI
import WidgetKit

struct WeatherLocationProvider<Options: WeatherLocationWidgetOptions>: AppIntentTimelineProvider {
    var alwaysDark = false

    func placeholder(in context: Context) -> DewPointWidgetEntry {
        DewPointWidgetEntry(date: .now, reading: DewPointWidgetLoader.sampleReading, message: nil, alwaysDark: alwaysDark)
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

private enum WeatherWidgetFamilies {
    static let home: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
    static var all: [WidgetFamily] {
        #if os(macOS)
        home
        #else
        home + [.accessoryCircular, .accessoryRectangular, .accessoryInline]
        #endif
    }
}

private extension DewPointWidgetEntry {
    var darkAppearance: Self {
        var entry = self
        entry.alwaysDark = true
        return entry
    }
}

struct JustWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "JustDewWeatherWidget", provider: DewPointWidgetProvider()) { entry in
            JustDewWidgetEntryView(entry: entry, metric: .temperature)
        }
        .configurationDisplayName("Weather")
        .description("Shows the weather at your current location, wherever you go.")
        .supportedFamilies(WeatherWidgetFamilies.all)
        .contentMarginsDisabled()
    }
}

struct SavedLocationWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "JustDewSavedLocationWeatherWidget", intent: WeatherWidgetIntent.self,
                               provider: WeatherLocationProvider<WeatherWidgetIntent>()) { entry in
            JustDewWidgetEntryView(entry: entry, metric: .temperature)
        }
        .configurationDisplayName("Weather · Location")
        .description("Choose Current Location or a saved city, with an optional dark appearance.")
        .supportedFamilies(WeatherWidgetFamilies.all)
        .contentMarginsDisabled()
    }
}

struct AlwaysDarkWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "JustDewAlwaysDarkWeatherWidget", provider: DewPointWidgetProvider()) { entry in
            JustDewWidgetEntryView(entry: entry.darkAppearance, metric: .temperature)
        }
        .configurationDisplayName("Weather · Always Dark")
        .description("An always dark weather widget that follows your current location.")
        .supportedFamilies(WeatherWidgetFamilies.home)
        .contentMarginsDisabled()
    }
}

struct AlwaysDarkLocationWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "JustDewAlwaysDarkLocationWeatherWidget", intent: DarkWeatherWidgetIntent.self,
                               provider: WeatherLocationProvider<DarkWeatherWidgetIntent>(alwaysDark: true)) { entry in
            JustDewWidgetEntryView(entry: entry, metric: .temperature)
        }
        .configurationDisplayName("Weather · Location · Always Dark")
        .description("Keep a saved city's weather visible in an always dark appearance.")
        .supportedFamilies(WeatherWidgetFamilies.home)
        .contentMarginsDisabled()
    }
}

struct CombinedWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "JustDewCombinedWeatherWidget", provider: DewPointWidgetProvider()) { entry in
            CombinedWeatherWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Weather + Dew Point")
        .description("Temperature, conditions, and dew point together for your current location.")
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
        .configurationDisplayName("Weather + Dew Point · Location")
        .description("Choose a saved city to see its weather and dew point together.")
        .supportedFamilies(WeatherWidgetFamilies.all)
        .contentMarginsDisabled()
    }
}

struct AlwaysDarkCombinedWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "JustDewAlwaysDarkCombinedWeatherWidget", provider: DewPointWidgetProvider()) { entry in
            CombinedWeatherWidgetEntryView(entry: entry.darkAppearance)
        }
        .configurationDisplayName("Weather + Dew Point · Always Dark")
        .description("An always dark widget showing weather and dew point at your current location.")
        .supportedFamilies(WeatherWidgetFamilies.home)
        .contentMarginsDisabled()
    }
}

struct AlwaysDarkLocationCombinedWeatherWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "JustDewAlwaysDarkLocationCombinedWeatherWidget", intent: DarkCombinedWeatherWidgetIntent.self,
                               provider: WeatherLocationProvider<DarkCombinedWeatherWidgetIntent>(alwaysDark: true)) { entry in
            CombinedWeatherWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Weather + Dew Point · Location · Always Dark")
        .description("Keep a saved city's weather and dew point visible in an always dark appearance.")
        .supportedFamilies(WeatherWidgetFamilies.home)
        .contentMarginsDisabled()
    }
}
