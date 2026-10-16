import AppIntents
import Foundation

struct DewPointLocationEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Location")
    static let defaultQuery = DewPointLocationQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static let current = DewPointLocationEntity(id: "current", name: "Current Location")
}

struct DewPointLocationQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [DewPointLocationEntity] {
        choices.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [DewPointLocationEntity] { choices }

    func entities(matching string: String) async throws -> [DewPointLocationEntity] {
        choices.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    private var choices: [DewPointLocationEntity] {
        [.current] + DewPointStore().loadLocations()
            .filter { $0.mode == .manual }
            .map { DewPointLocationEntity(id: $0.id, name: $0.compactDisplayName) }
    }
}

struct DewPointWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Dew Point Options"
    static let description = IntentDescription("Choose Current Location or a location saved in JustDew.")

    @Parameter(title: "Location")
    var location: DewPointLocationEntity?

    @Parameter(title: "Always Dark", default: false)
    var alwaysDark: Bool
}

struct DarkDewPointWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Dark Dew Point Options"
    static let description = IntentDescription("Choose a location for your always dark widget.")

    @Parameter(title: "Location")
    var location: DewPointLocationEntity?
}

#if os(watchOS)
struct WatchLocationDewPointIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Dew Point Location"
    static let description = IntentDescription("Choose Current Location or a city saved in JustDew on your Watch.")

    @Parameter(title: "Location")
    var location: DewPointLocationEntity?
}
#endif

// New configurations reuse stable location entities without changing shipped dew point intents.
protocol WeatherLocationWidgetOptions: WidgetConfigurationIntent {
    var location: DewPointLocationEntity? { get }
    var alwaysDark: Bool { get }
}

struct WeatherWidgetIntent: WeatherLocationWidgetOptions {
    static let title: LocalizedStringResource = "Weather Options"
    static let description = IntentDescription("Choose Current Location or a city saved in JustDew.")

    @Parameter(title: "Location")
    var location: DewPointLocationEntity?

    @Parameter(title: "Always Dark", default: false)
    var alwaysDark: Bool
}

struct DarkWeatherWidgetIntent: WeatherLocationWidgetOptions {
    static let title: LocalizedStringResource = "Dark Weather Options"
    static let description = IntentDescription("Choose a location for your always dark weather widget.")

    @Parameter(title: "Location")
    var location: DewPointLocationEntity?

    var alwaysDark: Bool { true }
}

struct CombinedWeatherWidgetIntent: WeatherLocationWidgetOptions {
    static let title: LocalizedStringResource = "Weather and Dew Point Options"
    static let description = IntentDescription("Choose a location to see its weather and dew point together.")

    @Parameter(title: "Location")
    var location: DewPointLocationEntity?

    @Parameter(title: "Always Dark", default: false)
    var alwaysDark: Bool
}

struct DarkCombinedWeatherWidgetIntent: WeatherLocationWidgetOptions {
    static let title: LocalizedStringResource = "Dark Weather and Dew Point Options"
    static let description = IntentDescription("Choose a location for your always dark combined widget.")

    @Parameter(title: "Location")
    var location: DewPointLocationEntity?

    var alwaysDark: Bool { true }
}

#if os(watchOS)
struct WatchLocationWeatherIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Weather Location"
    static let description = IntentDescription("Choose Current Location or a city saved in JustDew on your Watch.")

    @Parameter(title: "Location")
    var location: DewPointLocationEntity?
}
#endif
