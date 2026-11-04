import CoreLocation
import Foundation
import MapKit

enum LocationSearchService {
    static func resolve(_ completion: MKLocalSearchCompletion) async throws -> DewPointLocation {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = .address
        let response: MKLocalSearch.Response
        do {
            response = try await MKLocalSearch(request: request).start()
        } catch {
            throw normalizedGeocodingError(error)
        }
        guard let mapItem = response.mapItems.first else {
            throw DewPointError.geocodingNoResults
        }
        let fallback = [completion.title, completion.subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
        let names = displayNames(for: mapItem, fallback: fallback)
        return DewPointLocation(mode: .manual, name: names.name, shortName: names.shortName,
                                latitude: mapItem.location.coordinate.latitude,
                                longitude: mapItem.location.coordinate.longitude, savedAt: Date(),
                                timeZoneIdentifier: mapItem.timeZone?.identifier)
    }

    static func currentLocationNames(for location: CLLocation) async -> (name: String, shortName: String?, timeZoneIdentifier: String?) {
        do {
            if let request = MKReverseGeocodingRequest(location: location),
               let mapItem = try await request.mapItems.first {
                let names = displayNames(for: mapItem, fallback: "Current Location")
                return (names.name, names.shortName, mapItem.timeZone?.identifier)
            }
        } catch {
            return ("Current Location", nil, nil)
        }
        return ("Current Location", nil, nil)
    }

    static func timeZoneIdentifier(for location: CLLocation) async -> String? {
        guard let request = MKReverseGeocodingRequest(location: location),
              let items = try? await request.mapItems else { return nil }
        return items.first?.timeZone?.identifier
    }

    private static func displayNames(for mapItem: MKMapItem, fallback: String) -> (name: String, shortName: String?) {
        let shortName = preferredShortName(for: mapItem)
        if let shortName {
            return (shortName, shortName)
        }

        // Reverse geocoding can return a street or landmark as the map item's name.
        // Keep the supplied fallback rather than promoting that address to a city name.
        return (fallback, nil)
    }

    private static func preferredShortName(for mapItem: MKMapItem) -> String? {
        firstNonEmpty([
            mapItem.addressRepresentations?.cityWithContext,
            mapItem.addressRepresentations?.cityName,
            mapItem.addressRepresentations?.regionName
        ])
    }

    private static func normalizedGeocodingError(_ error: Error) -> DewPointError {
        let nsError = error as NSError

        if nsError.domain == "MKErrorDomain" {
            switch nsError.code {
            case 4:
                return .geocodingNoResults
            default:
                return .locationSearchUnavailable
            }
        }

        if nsError.domain == NSURLErrorDomain {
            return .networkUnavailable
        }

        return .locationSearchUnavailable
    }

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        values.compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }.first
    }
}
