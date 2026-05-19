import CoreLocation
import Foundation

@MainActor
final class OneShotLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var shouldRequestPermission = false
    private var requiresWidgetAuthorization = false

    override init() {
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
        if let continuation {
            continuation.resume(throwing: DewPointError.locationUnavailable)
            self.continuation = nil
        }

        shouldRequestPermission = requestPermission
        requiresWidgetAuthorization = requireWidgetAuthorization

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            continueOrRequestAuthorization()
        }
    }

    private func continueOrRequestAuthorization() {
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
            finish(with: .failure(error))
        }
    }

    private func finish(with result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil

        switch result {
        case .success(let location):
            continuation.resume(returning: location)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
