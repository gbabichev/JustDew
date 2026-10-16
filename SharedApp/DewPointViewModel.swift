import Combine
import CoreLocation
import Foundation
import WidgetKit

@MainActor
final class DewPointViewModel: ObservableObject {
    @Published var savedLocations: [DewPointLocation] = []
    @Published var reading: DewPointReading?
    @Published var configuredLocation: DewPointLocation?
    @Published var manualQuery = ""
    @Published var locationInputMode: DewPointLocationMode
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var authorizationStatus: CLAuthorizationStatus

    private let store = DewPointStore()
    private let locationProvider = OneShotLocationProvider()
    private var isRequestingCurrentLocation = false

    init() {
        savedLocations = store.loadLocations()
        let savedLocation = store.loadLocation()
        if let savedLocation {
            reading = store.loadReading(for: savedLocation)
        }
        configuredLocation = savedLocation
        locationInputMode = savedLocation?.mode ?? .current
        authorizationStatus = locationProvider.authorizationStatus
        DewPointStartupLog.event("model.restore", "configured=\(DewPointStartupLog.location(configuredLocation)) reading=\(DewPointStartupLog.reading(reading)) pages=[\(DewPointStartupLog.pages(savedLocations))]")
    }

    func selectLocation(_ location: DewPointLocation) {
        DewPointStartupLog.event("model.select.request", "target=\(DewPointStartupLog.location(location)) loading=\(isLoading) previous=\(DewPointStartupLog.location(configuredLocation))")
        guard !isLoading else { return }
        configuredLocation = location
        locationInputMode = location.mode
        manualQuery = ""
        reading = store.loadReading(for: location)
        DewPointStartupLog.event("model.select.cache", "target=\(DewPointStartupLog.location(location)) reading=\(DewPointStartupLog.reading(reading))")
        errorMessage = nil
        store.saveLocation(location)
        if let reading { store.saveReading(reading) }
        loadInitialReading()
    }

    func removeLocation(id: String) {
        guard let index = savedLocations.firstIndex(where: { $0.id == id }) else { return }
        removeLocations(at: IndexSet(integer: index))
    }

    func removeLocations(at offsets: IndexSet) {
        guard !isLoading else { return }
        let removedIDs = offsets.map { savedLocations[$0].id }
        savedLocations = savedLocations.filter { !removedIDs.contains($0.id) }
        store.saveLocations(savedLocations)
        if let configuredLocation, removedIDs.contains(configuredLocation.id) {
            if let next = savedLocations.first {
                selectLocation(next)
            } else {
                store.clearLocationAndReading()
                self.configuredLocation = nil
                reading = nil
                locationInputMode = .manual
            }
        }
        reloadWidgets()
    }

    private func remember(_ location: DewPointLocation) {
        var locations = savedLocations
        if let index = locations.firstIndex(where: { $0.id == location.id }) {
            locations[index] = location
        } else {
            locations.append(location)
        }
        savedLocations = DewPointStore.orderedLocations(locations)
        store.saveLocations(savedLocations)
    }

    func loadInitialReading() {
        DewPointStartupLog.event("model.loadInitial", "configured=\(DewPointStartupLog.location(configuredLocation)) reading=\(DewPointStartupLog.reading(reading)) loading=\(isLoading)")
        guard let configuredLocation else { return }
        // A widget can refresh the shared cache while the app is suspended.
        if let cached = store.loadReading(for: configuredLocation),
           cached.fetchedAt > (reading?.fetchedAt ?? .distantPast) {
            reading = cached
            DewPointStartupLog.event("model.cache.adopt", "reading=\(DewPointStartupLog.reading(cached))")
        }
        let needsRefresh = reading == nil || shouldRefresh(reading) || shouldRefreshForecast(reading)
        DewPointStartupLog.event("model.refresh.decision", "needsRefresh=\(needsRefresh) configured=\(DewPointStartupLog.location(configuredLocation))")
        guard needsRefresh else { return }
        refresh()
    }

    func refresh() {
        Task {
            await refreshNow()
        }
    }

    func refreshNow() async {
        guard !isLoading else { return }
        await refreshConfiguredLocation()
    }

    func useCurrentLocation() {
        if locationInputMode != .current {
            locationInputMode = .current
        }
        guard !isLoading, !isRequestingCurrentLocation else { return }
        isRequestingCurrentLocation = true
        Task {
            defer {
                isRequestingCurrentLocation = false
            }
            await setCurrentLocation()
        }
    }

    func useManualLocation() {
        guard !isLoading else { return }
        if locationInputMode != .manual {
            locationInputMode = .manual
        }
        Task {
            await setManualLocation()
        }
    }

    func useCurrentLocationIfNeeded() {
        guard locationInputMode == .current,
              configuredLocation?.mode != .current,
              !isLoading else {
            return
        }

        useCurrentLocation()
    }

    func clearLocation() {
        store.clearLocationAndReading()
        savedLocations = []
        configuredLocation = nil
        reading = nil
        manualQuery = ""
        errorMessage = nil
        reloadWidgets()
    }

    #if DEBUG
    func debugResetLocationState() {
        store.clearLocationAndReading()
        savedLocations = []
        configuredLocation = nil
        reading = nil
        manualQuery = ""
        locationInputMode = .manual
        errorMessage = nil
        isRequestingCurrentLocation = false
        reloadWidgets()
    }
    #endif

    private func refreshConfiguredLocation() async {
        guard let configuredLocation else {
            errorMessage = DewPointError.missingConfiguredLocation.localizedDescription
            return
        }

        if configuredLocation.mode == .current {
            await setCurrentLocation(requestPermission: false)
        } else {
            await fetchReading(for: configuredLocation)
        }
    }

    private func setCurrentLocation(requestPermission: Bool = true) async {
        await runLoadingOperation {
            let location = try await locationProvider.requestLocation(requestPermission: requestPermission)
            authorizationStatus = locationProvider.authorizationStatus

            let names = await LocationSearchService.currentLocationNames(for: location)
            let resolvedNames = currentLocationNames(names)
            let configuredLocation = DewPointLocation(
                mode: .current,
                name: resolvedNames.name,
                shortName: resolvedNames.shortName,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                savedAt: Date(),
                timeZoneIdentifier: names.timeZoneIdentifier
            )

            store.saveLocation(configuredLocation)
            remember(configuredLocation)
            reading = store.loadReading(for: configuredLocation)
            self.configuredLocation = configuredLocation
            locationInputMode = .current
            try await fetchReadingValue(for: configuredLocation)
            reloadWidgets()
        }
    }

    func addLocation(_ suggestion: LocationSuggestion) async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        errorMessage = nil
        do {
            let location = try await LocationSearchService.resolve(suggestion.completion)
            isLoading = false
            await addLocation(location)
            return configuredLocation?.id == location.id
        } catch {
            isLoading = false
            errorMessage = error.dewPointDisplayMessage
            return false
        }
    }

    func addLocation(_ location: DewPointLocation) async {
        guard !isLoading else { return }
        if let saved = savedLocations.first(where: { $0.id == location.id }) {
            selectLocation(saved)
            return
        }
        await runLoadingOperation {
            store.saveLocation(location)
            remember(location)
            reading = store.loadReading(for: location)
            configuredLocation = location
            locationInputMode = .manual
            manualQuery = ""
            // Save the choice even if weather is temporarily unavailable.
            reloadWidgets()
            try await fetchReadingValue(for: location)
            reloadWidgets()
        }
    }

    private func setManualLocation() async {
        do {
            let location = try await LocationSearchService.resolve(manualQuery)
            await addLocation(location)
        } catch {
            errorMessage = error.dewPointDisplayMessage
        }
    }

    private func fetchReading(for location: DewPointLocation) async {
        await runLoadingOperation {
            try await fetchReadingValue(for: location)
            reloadWidgets()
        }
    }

    private func fetchReadingValue(for location: DewPointLocation) async throws {
        DewPointStartupLog.event("fetch.begin", "target=\(DewPointStartupLog.location(location))")
        let reading = try await DewPointWeatherClient.reading(for: location)
        DewPointStartupLog.event("fetch.received", "configuredBeforeApply=\(DewPointStartupLog.location(configuredLocation)) reading=\(DewPointStartupLog.reading(reading))")
        store.saveReading(reading)
        let storedReading = store.loadReading(for: reading.location) ?? reading
        self.reading = storedReading
        configuredLocation = storedReading.location
        DewPointStartupLog.event("fetch.applied", "configured=\(DewPointStartupLog.location(configuredLocation)) reading=\(DewPointStartupLog.reading(self.reading))")
        if let index = savedLocations.firstIndex(where: { $0.id == storedReading.location.id }),
           savedLocations[index] != storedReading.location {
            savedLocations[index] = storedReading.location
            store.saveLocations(savedLocations)
        }
    }

    private func runLoadingOperation(_ operation: () async throws -> Void) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        DewPointStartupLog.event("loading.begin", "configured=\(DewPointStartupLog.location(configuredLocation))")
        defer {
            isLoading = false
            authorizationStatus = locationProvider.authorizationStatus
            DewPointStartupLog.event("loading.end", "configured=\(DewPointStartupLog.location(configuredLocation)) reading=\(DewPointStartupLog.reading(reading))")
        }

        do {
            try await operation()
        } catch {
            DewPointStartupLog.event("loading.error", "domain=\((error as NSError).domain) code=\((error as NSError).code)")
            errorMessage = error.dewPointDisplayMessage
        }
    }

    private func shouldRefresh(_ reading: DewPointReading?) -> Bool {
        guard let reading else { return true }
        return Date().timeIntervalSince(reading.fetchedAt) > DewPointConfiguration.refreshInterval
    }

    private func shouldRefreshForecast(_ reading: DewPointReading?) -> Bool {
        guard let reading else { return true }
        guard reading.dailyWeather != nil else { return true }
        // Refresh caches written before hourly weather details were stored.
        guard reading.dailyForecastPoints.contains(where: { $0.weather != nil }) else { return true }
        let calendar = reading.forecastCalendar
        let start = calendar.startOfDay(for: Date())
        guard let lastDayStart = calendar.date(byAdding: .day, value: DewPointConfiguration.forecastDayCount - 1, to: start) else {
            return reading.dailyForecastPoints.isEmpty
        }

        return !reading.dailyForecastPoints.contains { $0.date >= lastDayStart }
    }

    private func currentLocationNames(_ names: (name: String, shortName: String?, timeZoneIdentifier: String?)) -> (name: String, shortName: String?) {
        let resolvedLocation = DewPointLocation(
            mode: .current,
            name: names.name,
            shortName: names.shortName,
            latitude: configuredLocation?.latitude ?? 0,
            longitude: configuredLocation?.longitude ?? 0,
            savedAt: configuredLocation?.savedAt ?? Date()
        )

        guard !resolvedLocation.hasSpecificDisplayName,
              let configuredLocation,
              configuredLocation.mode == .current,
              configuredLocation.hasSpecificDisplayName else {
            return (names.name, names.shortName)
        }

        return (configuredLocation.name, configuredLocation.shortName)
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
