import CoreLocation
import Foundation
import MapKit

enum LocationSearchService {
    static func resolve(_ query: String) async throws -> DewPointLocation {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { throw DewPointError.geocodingNoResults }

        guard let request = MKGeocodingRequest(addressString: trimmedQuery) else {
            throw DewPointError.geocodingNoResults
        }

        let mapItems: [MKMapItem]
        do {
            mapItems = try await request.mapItems
        } catch {
            throw normalizedGeocodingError(error)
        }

        guard let mapItem = mapItems.first else {
            throw DewPointError.geocodingNoResults
        }

        let names = displayNames(for: mapItem, fallback: trimmedQuery)
        return DewPointLocation(
            mode: .manual,
            name: names.name,
            shortName: names.shortName,
            latitude: mapItem.location.coordinate.latitude,
            longitude: mapItem.location.coordinate.longitude,
            savedAt: Date()
        )
    }

    static func currentLocationName(for location: CLLocation) async -> String {
        await currentLocationNames(for: location).name
    }

    static func currentLocationNames(for location: CLLocation) async -> (name: String, shortName: String?) {
        do {
            if let request = MKReverseGeocodingRequest(location: location),
               let mapItem = try await request.mapItems.first {
                return displayNames(for: mapItem, fallback: "Current Location")
            }
        } catch {
            return ("Current Location", nil)
        }
        return ("Current Location", nil)
    }

    private static func displayNames(for mapItem: MKMapItem, fallback: String) -> (name: String, shortName: String?) {
        let shortName = preferredShortName(for: mapItem)
        if let shortName {
            return (shortName, shortName)
        }

        let parts = [
            mapItem.name,
            mapItem.addressRepresentations?.regionName,
            mapItem.address?.shortAddress,
            mapItem.address?.fullAddress
        ].compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }.reduce(into: [String]()) { result, value in
            if !result.contains(value) {
                result.append(value)
            }
        }

        return (parts.isEmpty ? fallback : parts.joined(separator: ", "), shortName)
    }

    private static func preferredShortName(for mapItem: MKMapItem) -> String? {
        firstNonEmpty([
            cityState(from: mapItem.address?.shortAddress),
            cityState(from: mapItem.address?.fullAddress),
            cityState(from: mapItem.addressRepresentations?.regionName)
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

    private static func cityState(from address: String?) -> String? {
        guard let address else { return nil }
        let components = address
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let stateIndex = components.firstIndex(where: { component in
            component.range(of: #"^[A-Z]{2}(?:\s+\d{5})?$"#, options: .regularExpression) != nil
        }), stateIndex > components.startIndex else {
            return nil
        }

        let city = components[components.index(before: stateIndex)]
        let state = components[stateIndex]
            .split(separator: " ")
            .first
            .map(String.init) ?? components[stateIndex]

        return "\(city), \(state)"
    }

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        values.compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }.first
    }
}
