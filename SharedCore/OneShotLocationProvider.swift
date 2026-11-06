import CoreLocation
import Foundation

@MainActor
final class OneShotLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager: CLLocationManager
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var shouldRequestPermission = false
    private var requiresWidgetAuthorization = false
    private var requestID: UUID?
    private var timeoutTask: Task<Void, Never>?
    private let timeout: Duration

    init(manager: CLLocationManager = CLLocationManager(), timeout: Duration = .seconds(10)) {
        self.manager = manager
        self.timeout = timeout
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    var isAuthorizedForWidgetUpdates: Bool {
        #if os(watchOS)
        true
        #else
        manager.isAuthorizedForWidgetUpdates
        #endif
    }

    func requestLocation(
        requestPermission: Bool,
        requireWidgetAuthorization: Bool = false
    ) async throws -> CLLocation {
        try Task.checkCancellation()
        finish(with: .failure(DewPointError.locationUnavailable))

        let id = UUID()
        requestID = id
        shouldRequestPermission = requestPermission
        requiresWidgetAuthorization = requireWidgetAuthorization

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                continueOrRequestAuthorization()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self, self.requestID == id else { return }
                self.finish(with: .failure(CancellationError()))
            }
        }
    }

    private func continueOrRequestAuthorization() {
        guard continuation != nil else { return }
        if requiresWidgetAuthorization && !isAuthorizedForWidgetUpdates {
            finish(with: .failure(DewPointError.widgetLocationUnavailable))
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            guard shouldRequestPermission else {
                finish(with: .failure(DewPointError.permissionDenied))
                return
            }
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            // Start after permission is granted; never time out the permission prompt.
            if timeoutTask == nil {
                let id = requestID
                let timeout = timeout
                timeoutTask = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: timeout) }
                    catch { return }
                    guard let self, self.requestID == id else { return }
                    self.finish(with: .failure(DewPointError.locationUnavailable))
                }
            }
            manager.requestLocation()
        case .denied, .restricted:
            finish(with: .failure(DewPointError.permissionDenied))
        @unknown default:
            finish(with: .failure(DewPointError.locationUnavailable))
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            continueOrRequestAuthorization()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.last else {
                finish(with: .failure(DewPointError.locationUnavailable))
                return
            }
            finish(with: .success(location))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let locationError = error as? CLError {
                finish(with: .failure(locationError.code == .denied
                    ? DewPointError.permissionDenied : DewPointError.locationUnavailable))
            } else {
                finish(with: .failure(error))
            }
        }
    }

    private func finish(with result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        requestID = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()

        switch result {
        case .success(let location):
            continuation.resume(returning: location)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
