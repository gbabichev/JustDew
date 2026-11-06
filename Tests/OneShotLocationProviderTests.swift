import CoreLocation
import Foundation

// Standalone: compile this file with SharedCore/OneShotLocationProvider.swift.
enum DewPointError: Error, Equatable {
    case locationUnavailable, permissionDenied, widgetLocationUnavailable
}

private final class SilentLocationManager: CLLocationManager {
    override var authorizationStatus: CLAuthorizationStatus { .authorizedAlways }
    override func requestLocation() {}
    override func stopUpdatingLocation() {}
}

@main
struct OneShotLocationProviderTests {
    @MainActor
    static func main() async throws {
        let manager = SilentLocationManager()
        let provider = OneShotLocationProvider(manager: manager, timeout: .milliseconds(50))
        do {
            _ = try await provider.requestLocation(requestPermission: false)
            preconditionFailure("A silent location request must time out")
        } catch {
            precondition(error as? DewPointError == .locationUnavailable)
        }

        // Late callbacks after timeout must be harmless, and the next request must work.
        provider.locationManager(manager, didUpdateLocations: [CLLocation(latitude: 1, longitude: 2)])
        await Task.yield()
        let retry = Task { try await provider.requestLocation(requestPermission: false) }
        try await Task.sleep(for: .milliseconds(10))
        provider.locationManager(manager, didUpdateLocations: [CLLocation(latitude: 3, longitude: 4)])
        let location = try await retry.value
        precondition(location.coordinate.latitude == 3)

        let cancelled = Task { try await provider.requestLocation(requestPermission: false) }
        try await Task.sleep(for: .milliseconds(10))
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            preconditionFailure("Cancelled requests must finish promptly")
        } catch is CancellationError {
            // Expected.
        }

        let afterCancellation = Task { try await provider.requestLocation(requestPermission: false) }
        try await Task.sleep(for: .milliseconds(10))
        provider.locationManager(manager, didUpdateLocations: [CLLocation(latitude: 5, longitude: 6)])
        let nextLocation = try await afterCancellation.value
        precondition(nextLocation.coordinate.latitude == 5)
        print("Location timeout, late callback, retry, and cancellation checks passed")
    }
}
