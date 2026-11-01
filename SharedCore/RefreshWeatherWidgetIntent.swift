import AppIntents

#if os(iOS) || os(macOS)
struct RefreshWeatherWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Weather"
    static let isDiscoverable = false

    @Parameter(title: "Location ID")
    var locationID: String

    init() {}

    init(locationID: String) {
        self.locationID = locationID
    }

    func perform() async throws -> some IntentResult {
        do {
            // Finish writing fresh data before WidgetKit automatically reloads the timeline.
            _ = try await DewPointWidgetLoader.loadReading(locationID: locationID, forceRefresh: true)
        } catch {
            // Preserve the last successful reading and its timestamp when offline.
            // The timeline provider already handles cached fallback and error messages.
        }
        return .result()
    }
}
#endif
