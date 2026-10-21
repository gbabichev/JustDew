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
        let task = Task {
            defer { savedLocationsRefreshTask = nil }
            let selectedID = configuredLocation?.id
            if configuredLocation != nil,
               force || shouldRefresh(reading) || shouldRefreshForecast(reading) {
                await refreshNow()
                // A failed selection refresh should not prevent the other cities updating.
            }
            let locations = savedLocations
            for location in locations where location.id != selectedID {
                let cached = cachedReadings[location.id]
                guard force || shouldRefresh(cached) || shouldRefreshForecast(cached) else { continue }
                do {
                    let resolved = location.mode == .current
                        ? try await resolvedCurrentLocation() : location
                    let result = try await fetchWeather(resolved)
                    // The user can remove or change locations while this request runs.
                    guard savedLocations.contains(where: { $0.id == location.id }) else { continue }
                    store.saveCachedReading(result)
                    let cached = store.loadReading(for: resolved) ?? result
                    cachedReadings[location.id] = cached
                    if location != cached.location { remember(cached.location) }
                    if configuredLocation?.id == location.id {
                        reading = cached
                        configuredLocation = cached.location
                        store.saveReading(cached)
                    }
                } catch {
                    // Keep the last successful reading and continue refreshing the rest.
                }
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

        if configuredLocation.mode == .current {
            await setCurrentLocation(requestPermission: false)
        } else {
            await fetchReading(for: configuredLocation)
        }
    }

    private func setCurrentLocation(requestPermission: Bool = true) async {
        await runLoadingOperation {
            let configuredLocation = try await resolvedCurrentLocation(requestPermission: requestPermission)

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
            try await fetchReadingValue(for: location)
            reloadWidgets()
        }
    }

    private func fetchReadingValue(for location: DewPointLocation) async throws {
        let reading = try await fetchWeather(location)
        store.saveReading(reading)
        let storedReading = store.loadReading(for: reading.location) ?? reading
        cachedReadings[storedReading.location.id] = storedReading
        self.reading = storedReading
        configuredLocation = storedReading.location
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
