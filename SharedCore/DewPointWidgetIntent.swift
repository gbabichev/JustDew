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

    func defaultResult() async -> DewPointLocationEntity? { .current }

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

struct DewPointWidgetIntent: WeatherLocationWidgetOptions {
    static let title: LocalizedStringResource = "Dew Point Options"
    // Used by App Intents metadata extraction.
    // periphery:ignore
    static let description = IntentDescription("Choose Current Location or a location saved in JustDew.")

    @Parameter(title: "Location")
    var location: DewPointLocationEntity?

    @Parameter(title: "Always Dark", default: false)
    var alwaysDark: Bool

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$location
            \.$alwaysDark
        }
    }
}

#if os(watchOS)
struct WatchLocationDewPointIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Dew Point Location"
    // Used by App Intents metadata extraction.
    // periphery:ignore
    static let description = IntentDescription("Choose Current Location or a city saved in JustDew on your Watch.")

    @Parameter(title: "Location")
    var location: DewPointLocationEntity?
}
#endif

// The three editable widgets share the same location and appearance options.
protocol WeatherLocationWidgetOptions: WidgetConfigurationIntent {
    var location: DewPointLocationEntity? { get }
    var alwaysDark: Bool { get }
}

struct WeatherWidgetIntent: WeatherLocationWidgetOptions {
    static let title: LocalizedStringResource = "Weather Options"
    // Used by App Intents metadata extraction.
    // periphery:ignore
    static let description = IntentDescription("Choose Current Location or a city saved in JustDew.")

    @Parameter(title: "Location")
    var location: DewPointLocationEntity?

    @Parameter(title: "Always Dark", default: false)
    var alwaysDark: Bool

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$location
            \.$alwaysDark
        }
    }
}

struct CombinedWeatherWidgetIntent: WeatherLocationWidgetOptions {
    static let title: LocalizedStringResource = "Weather and Dew Point Options"
    // Used by App Intents metadata extraction.
    // periphery:ignore
    static let description = IntentDescription("Choose a location to see its weather and dew point together.")

    @Parameter(title: "Location")
    var location: DewPointLocationEntity?

    @Parameter(title: "Always Dark", default: false)
    var alwaysDark: Bool

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$location
            \.$alwaysDark
        }
    }
}

#if os(watchOS)
struct WatchLocationWeatherIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Weather Location"
    // Used by App Intents metadata extraction.
    // periphery:ignore
    static let description = IntentDescription("Choose Current Location or a city saved in JustDew on your Watch.")

    @Parameter(title: "Location")
    var location: DewPointLocationEntity?
}
#endif
