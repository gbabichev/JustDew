import MapKit
import Observation

struct LocationSuggestion: Identifiable {
    let title: String
    let subtitle: String
    let completion: MKLocalSearchCompletion

    var id: String { title + "\u{001F}" + subtitle }
}

@MainActor
@Observable
final class LocationAutocomplete: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {
    private(set) var results: [LocationSuggestion] = []
    private(set) var isSearching = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let makeCompleter: () -> MKLocalSearchCompleter
    @ObservationIgnored private var completer: MKLocalSearchCompleter?
    @ObservationIgnored private var pendingSearch: Task<Void, Never>?

    init(makeCompleter: @escaping () -> MKLocalSearchCompleter = { MKLocalSearchCompleter() }) {
        self.makeCompleter = makeCompleter
        super.init()
    }

    func updateQuery(_ query: String) {
        cancel()
        results = []
        errorMessage = nil
        let fragment = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fragment.isEmpty else { return }
        isSearching = true
        pendingSearch = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
                try Task.checkCancellation()
                self?.startSearch(fragment)
            } catch {
                // A newer query or dismissal cancelled the debounce.
            }
        }
    }

    func cancel() {
        pendingSearch?.cancel()
        pendingSearch = nil
        completer?.delegate = nil
        completer?.cancel()
        completer = nil
        isSearching = false
    }

    private func startSearch(_ fragment: String) {
        // A separate completer per query makes late callbacks identifiable.
        let request = makeCompleter()
        request.resultTypes = .address
        request.addressFilter = MKAddressFilter(including: [.locality, .postalCode])
        request.delegate = self
        completer = request
        request.queryFragment = fragment
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard completer === self.completer else { return }
        var seen = Set<String>()
        results = completer.results.compactMap { completion in
            let suggestion = LocationSuggestion(title: completion.title, subtitle: completion.subtitle,
                                                completion: completion)
            return seen.insert(suggestion.id).inserted ? suggestion : nil
        }
        isSearching = false
        errorMessage = nil
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        guard completer === self.completer else { return }
        results = []
        isSearching = false
        errorMessage = error.dewPointDisplayMessage
    }
}
