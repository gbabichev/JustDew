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
    }

    func selectLocation(_ location: DewPointLocation) {
        guard !isLoading else { return }
        configuredLocation = location
        locationInputMode = location.mode
        manualQuery = ""
        reading = store.loadReading(for: location)
        errorMessage = nil
        store.saveLocation(location)
        if let reading { store.saveReading(reading) }
        reloadWidgets()
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
        if let index = savedLocations.firstIndex(where: { $0.id == location.id }) {
            savedLocations[index] = location
        } else {
            savedLocations.append(location)
        }
        store.saveLocations(savedLocations)
    }

    func loadInitialReading() {
        guard configuredLocation != nil else { return }
        guard reading == nil || shouldRefresh(reading) || shouldRefreshForecast(reading) else { return }
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
                savedAt: Date()
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

    private func setManualLocation() async {
        await runLoadingOperation {
            let configuredLocation = try await LocationSearchService.resolve(manualQuery)
            store.saveLocation(configuredLocation)
            remember(configuredLocation)
            reading = store.loadReading(for: configuredLocation)
            self.configuredLocation = configuredLocation
            locationInputMode = .manual
            manualQuery = configuredLocation.compactDisplayName
            try await fetchReadingValue(for: configuredLocation)
            manualQuery = ""
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
        let reading = try await DewPointWeatherClient.reading(for: location)
        store.saveReading(reading)
        self.reading = reading
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
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let fifthDayStart = calendar.date(byAdding: .day, value: 5, to: start) else {
            return reading.dailyForecastPoints.isEmpty
        }

        return !reading.dailyForecastPoints.contains { $0.date >= fifthDayStart }
    }

    private func currentLocationNames(_ names: (name: String, shortName: String?)) -> (name: String, shortName: String?) {
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
            return names
        }

        return (configuredLocation.name, configuredLocation.shortName)
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
