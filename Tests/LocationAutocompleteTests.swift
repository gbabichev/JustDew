import Foundation
import MapKit

// Compile with SharedApp/LocationAutocomplete.swift and SharedCore/DewPointModels.swift.
private final class StubCompletion: MKLocalSearchCompletion {
    private let placeTitle: String
    private let placeSubtitle: String

    init(_ title: String, subtitle: String) {
        placeTitle = title
        placeSubtitle = subtitle
        super.init()
    }

    override var title: String { placeTitle }
    override var subtitle: String { placeSubtitle }
}

private final class StubCompleter: MKLocalSearchCompleter {
    private var fragment = ""
    var matches: [MKLocalSearchCompletion] = []
    var wasCancelled = false

    // Keep the test offline: assigning a query never calls MapKit's implementation.
    override var queryFragment: String {
        get { fragment }
        set { fragment = newValue }
    }
    override var results: [MKLocalSearchCompletion] { matches }
    override func cancel() { wasCancelled = true }
}

@main
struct LocationAutocompleteTests {
    @MainActor
    static func main() async throws {
        var requests: [StubCompleter] = []
        let search = LocationAutocomplete {
            let request = StubCompleter()
            requests.append(request)
            return request
        }

        search.updateQuery("Char")
        try await Task.sleep(for: .milliseconds(400))
        let old = requests[0]
        old.matches = [StubCompletion("Charlotte", subtitle: "NC, United States")]
        search.completerDidUpdateResults(old)
        precondition(search.results.first?.title == "Charlotte")

        search.updateQuery("Los ange")
        precondition(search.results.isEmpty, "Changing text must immediately remove old suggestions")
        precondition(search.isSearching)
        precondition(old.wasCancelled)
        search.completerDidUpdateResults(old)
        search.completer(old, didFailWithError: DewPointError.networkUnavailable)
        precondition(search.results.isEmpty && search.errorMessage == nil && search.isSearching,
                     "Late results and errors from the old query must not affect the new query")

        try await Task.sleep(for: .milliseconds(400))
        let latest = requests[1]
        let losAngeles = StubCompletion("Los Angeles", subtitle: "CA, United States")
        latest.matches = [losAngeles, losAngeles]
        search.completerDidUpdateResults(latest)
        precondition(search.results.count == 1, "Duplicate suggestions should appear once")
        precondition(search.results.first?.title == "Los Angeles")
        precondition(search.results.first?.subtitle == "CA, United States")
        precondition(search.results.first?.completion === losAngeles, "Retain the exact selected completion")
        precondition(!search.isSearching)

        search.updateQuery("Houston")
        search.updateQuery("  ")
        try await Task.sleep(for: .milliseconds(400))
        precondition(requests.count == 2, "Clearing text must cancel a pending lookup")
        precondition(search.results.isEmpty && !search.isSearching)
        search.cancel()
        print("LocationAutocomplete tests passed")
    }
}
