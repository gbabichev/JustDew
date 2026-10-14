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
