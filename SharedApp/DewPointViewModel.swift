import Combine
import CoreLocation
import Foundation
import WidgetKit

@MainActor
final class DewPointViewModel: ObservableObject {
    @Published var savedLocations: [DewPointLocation] = []
    @Published var reading: DewPointReading?
    @Published var configuredLocation: DewPointLocation?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var authorizationStatus: CLAuthorizationStatus

    @Published private(set) var cachedReadings: [String: DewPointReading] = [:]

    private let store: DewPointStore
    private let fetchWeather: @Sendable (DewPointLocation) async throws -> DewPointReading
    private var savedLocationsRefreshTask: Task<Void, Never>?
    private var hasRefreshedOnLaunch = false
    private var weatherRequests: [String: Task<DewPointReading, Error>] = [:]
    @Published private var refreshingLocationIDs: Set<String> = []
    private let locationProvider = OneShotLocationProvider()
    private var isRequestingCurrentLocation = false

    init(
        store: DewPointStore? = nil,
        fetchWeather: @escaping @Sendable (DewPointLocation) async throws -> DewPointReading = {
            try await DewPointWeatherClient.reading(for: $0)
        }
    ) {
        let store = store ?? DewPointStore()
        self.store = store
        self.fetchWeather = fetchWeather
        let locations = store.loadLocations()
        savedLocations = locations
        cachedReadings = Dictionary(uniqueKeysWithValues: locations.compactMap { location in
            store.loadReading(for: location).map { (location.id, $0) }
        })
        let savedLocation = store.loadLocation()
        if let savedLocation {
            reading = store.loadReading(for: savedLocation)
        }
        configuredLocation = savedLocation
        authorizationStatus = locationProvider.authorizationStatus
    }

    func selectLocation(_ location: DewPointLocation) {
        guard !isLoading else { return }
        configuredLocation = location
        reading = store.loadReading(for: location)
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

    func cachedReading(for location: DewPointLocation) -> DewPointReading? {
        if configuredLocation?.id == location.id { return reading }
        return cachedReadings[location.id]
    }

    /// Shared by launch and foreground activation on iOS, macOS, and watchOS.
    @discardableResult
    func refreshSavedLocationsIfNeeded() -> Task<Void, Never> {
        if let savedLocationsRefreshTask { return savedLocationsRefreshTask }
        let force = !hasRefreshedOnLaunch
        hasRefreshedOnLaunch = true
        // Adopt widget updates and publish them for every row, not just the selection.
        cachedReadings = Dictionary(uniqueKeysWithValues: savedLocations.compactMap { location in
            store.loadReading(for: location).map { (location.id, $0) }
        })
        if let configuredLocation, let cached = cachedReadings[configuredLocation.id],
           cached.fetchedAt > (reading?.fetchedAt ?? .distantPast) {
            reading = cached
        }
        let refreshStartedAt = Date()
        let task = Task {
            defer { savedLocationsRefreshTask = nil }
            let selectedID = configuredLocation?.id
            let locations = savedLocations.sorted { $0.id == selectedID && $1.id != selectedID }
            for location in locations {
                guard savedLocations.contains(where: { $0.id == location.id }) else { continue }
                let cached = cachedReadings[location.id]
                // Selecting a city can already have refreshed it during this pass.
                let needsRefresh = shouldRefresh(cached) || shouldRefreshForecast(cached)
                    || (force && (cached?.fetchedAt ?? .distantPast) < refreshStartedAt)
                guard needsRefresh else { continue }
                await refreshSilently(for: location)
            }
            reloadWidgets()
        }
        savedLocationsRefreshTask = task
        return task
    }

    func loadInitialReading() {
        guard let configuredLocation else { return }
        // A widget can refresh the shared cache while the app is suspended.
        if let cached = store.loadReading(for: configuredLocation),
           cached.fetchedAt > (reading?.fetchedAt ?? .distantPast) {
            reading = cached
        }
        let needsRefresh = reading == nil || shouldRefresh(reading) || shouldRefreshForecast(reading)
        guard needsRefresh else { return }
        let location = configuredLocation
        Task {
            await refreshSilently(for: location)
            reloadWidgets()
        }
    }

    /// Cached pages update silently; a page without data still explains that it is loading.
    func isLoadingReading(for location: DewPointLocation) -> Bool {
        isLoading || (cachedReading(for: location) == nil && refreshingLocationIDs.contains(location.id))
    }

    private func refreshSilently(for location: DewPointLocation) async {
        do {
            let result = try await weatherReading(for: location, resolveCurrentLocation: true)
            applyReading(result, requestedLocationID: location.id)
        } catch {
            // Existing readings and timestamps stay visible on transient refresh failures.
            if configuredLocation?.id == location.id, reading == nil {
                errorMessage = error.dewPointDisplayMessage
            }
        }
    }

    /// Share requests between startup, page selection, and manual refresh.
    private func weatherReading(
        for location: DewPointLocation,
        resolveCurrentLocation: Bool = false
    ) async throws -> DewPointReading {
        if let request = weatherRequests[location.id] { return try await request.value }
        let request = Task {
            let resolved = resolveCurrentLocation && location.mode == .current
                ? try await resolvedCurrentLocation() : location
            return try await fetchWeather(resolved)
        }
        weatherRequests[location.id] = request
        refreshingLocationIDs.insert(location.id)
        defer {
            weatherRequests[location.id] = nil
            refreshingLocationIDs.remove(location.id)
        }
        return try await request.value
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
        guard !isLoading, !isRequestingCurrentLocation else { return }
        isRequestingCurrentLocation = true
        Task {
            defer {
                isRequestingCurrentLocation = false
            }
            await setCurrentLocation()
        }
    }

    private func refreshConfiguredLocation() async {
        guard let configuredLocation else {
            errorMessage = DewPointError.missingConfiguredLocation.localizedDescription
            return
        }

        await fetchReading(for: configuredLocation)
    }

    private func setCurrentLocation() async {
        await runLoadingOperation {
            let configuredLocation = try await resolvedCurrentLocation(requestPermission: true)

            store.saveLocation(configuredLocation)
            remember(configuredLocation)
            reading = store.loadReading(for: configuredLocation)
            self.configuredLocation = configuredLocation
            try await fetchReadingValue(for: configuredLocation)
            reloadWidgets()
        }
    }

    private func resolvedCurrentLocation(requestPermission: Bool = false) async throws -> DewPointLocation {
        let location = try await locationProvider.requestLocation(requestPermission: requestPermission)
        authorizationStatus = locationProvider.authorizationStatus
        let names = await LocationSearchService.currentLocationNames(for: location)
        let resolvedNames = currentLocationNames(names)
        return DewPointLocation(
            mode: .current, name: resolvedNames.name, shortName: resolvedNames.shortName,
            latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
            savedAt: Date(), timeZoneIdentifier: names.timeZoneIdentifier
        )
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
            // Save the choice even if weather is temporarily unavailable.
            reloadWidgets()
            try await fetchReadingValue(for: location)
            reloadWidgets()
        }
    }

    private func fetchReading(for location: DewPointLocation) async {
        await runLoadingOperation {
            try await fetchReadingValue(for: location, resolveCurrentLocation: true)
            reloadWidgets()
        }
    }

    private func fetchReadingValue(for location: DewPointLocation, resolveCurrentLocation: Bool = false) async throws {
        let result = try await weatherReading(for: location, resolveCurrentLocation: resolveCurrentLocation)
        applyReading(result, requestedLocationID: location.id)
    }

    private func applyReading(_ result: DewPointReading, requestedLocationID: String) {
        // Background work must not re-add deleted cities or change the user's selection.
        guard result.location.id == requestedLocationID,
              savedLocations.contains(where: { $0.id == requestedLocationID }) else { return }
        if let cached = cachedReadings[requestedLocationID], cached.fetchedAt > result.fetchedAt { return }
        store.saveCachedReading(result)
        let storedReading = store.loadReading(for: result.location) ?? result
        cachedReadings[requestedLocationID] = storedReading
        if let index = savedLocations.firstIndex(where: { $0.id == requestedLocationID }),
           savedLocations[index] != storedReading.location {
            savedLocations[index] = storedReading.location
            store.saveLocations(savedLocations)
        }
        if configuredLocation?.id == requestedLocationID {
            reading = storedReading
            configuredLocation = storedReading.location
            errorMessage = nil
            store.saveReading(storedReading)
        }
    }

    private func runLoadingOperation(_ operation: () async throws -> Void) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            authorizationStatus = locationProvider.authorizationStatus
        }

        do {
            try await operation()
        } catch {
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
