import Combine
import CoreLocation
import Foundation
import WidgetKit

@MainActor
final class DewPointViewModel: ObservableObject {
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
        let savedLocation = store.loadLocation()
        reading = store.loadReading()
        configuredLocation = savedLocation
        locationInputMode = savedLocation?.mode ?? .current
        if savedLocation?.mode == .manual {
            manualQuery = savedLocation?.compactDisplayName ?? ""
        }
        authorizationStatus = locationProvider.authorizationStatus
    }

    func loadInitialReading() {
        guard reading == nil || shouldRefresh(reading) else { return }
        refresh()
    }

    func refresh() {
        Task {
            await refreshConfiguredLocation()
        }
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
        configuredLocation = nil
        reading = nil
        manualQuery = ""
        errorMessage = nil
        reloadWidgets()
    }

    #if DEBUG
    func debugResetLocationState() {
        store.clearLocationAndReading()
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
            self.configuredLocation = configuredLocation
            locationInputMode = .manual
            manualQuery = configuredLocation.compactDisplayName
            try await fetchReadingValue(for: configuredLocation)
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
              configuredLocation.hasSpecificDisplayName else {
            return names
        }

        return (configuredLocation.name, configuredLocation.shortName)
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: DewPointConfiguration.appWidgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: DewPointConfiguration.watchWidgetKind)
    }
}
