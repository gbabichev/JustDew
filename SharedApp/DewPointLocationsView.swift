import SwiftUI

struct DewPointAppView: View {
    @StateObject private var viewModel = DewPointViewModel()
    @State private var showsLocations = false
    @State private var selectedID = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.savedLocations.isEmpty {
                    DewPointLocationsList(viewModel: viewModel)
                } else {
                    #if os(iOS)
                    TabView(selection: $selectedID) {
                        ForEach(viewModel.savedLocations) { location in
                            DewPointLocationPage(viewModel: viewModel, location: location)
                                .tag(location.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                    .allowsHitTesting(!viewModel.isLoading)
                    #else
                    if let location = viewModel.configuredLocation {
                        DewPointLocationPage(viewModel: viewModel, location: location)
                    }
                    #endif
                }
            }
            #if os(iOS)
            // Match the forms across the navigation bar and bottom safe area.
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .navigationTitle(viewModel.configuredLocation?.compactDisplayName ?? "JustDew")
            .toolbar {
                ToolbarItem {
                    Button {
                        showsLocations = true
                    } label: {
                        Label("Locations", systemImage: "list.bullet")
                    }
                }
            }
            .sheet(isPresented: $showsLocations) {
                NavigationStack {
                    DewPointLocationsList(viewModel: viewModel, onSelection: { showsLocations = false })
                        .navigationTitle("Locations")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showsLocations = false }
                            }
                        }
                }
                #if os(macOS)
                .frame(minWidth: 400, minHeight: 450)
                #endif
            }
        }
        .task {
            selectedID = viewModel.configuredLocation?.id ?? ""
            viewModel.loadInitialReading()
        }
        .onChange(of: selectedID) { _, id in
            guard id != viewModel.configuredLocation?.id,
                  let location = viewModel.savedLocations.first(where: { $0.id == id }) else { return }
            viewModel.selectLocation(location)
        }
        .onChange(of: viewModel.configuredLocation?.id) { _, id in
            selectedID = id ?? ""
        }
    }
}

private struct DewPointLocationsList: View {
    @ObservedObject var viewModel: DewPointViewModel
    var onSelection: () -> Void = {}
    @State private var query = ""
    @State private var results: [DewPointLocation] = []
    @State private var isSearching = false
    @State private var searchError: String?

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            if trimmedQuery.isEmpty {
                Section {
                    ForEach(viewModel.savedLocations) { location in
                        Button {
                            viewModel.selectLocation(location)
                            onSelection()
                        } label: {
                            SavedLocationRow(location: location,
                                             isSelected: viewModel.configuredLocation?.id == location.id)
                        }
                        .disabled(viewModel.isLoading)
                        #if os(macOS)
                        .contextMenu {
                            Button("Remove Location", role: .destructive) {
                                viewModel.removeLocation(id: location.id)
                            }
                            .disabled(viewModel.isLoading)
                        }
                        #endif
                    }
                    .onDelete(perform: viewModel.removeLocations)
                } header: {
                    Text("Your Locations")
                } footer: {
                    Text("Search for a city or ZIP code to add another location.")
                }

                if !viewModel.savedLocations.contains(where: { $0.mode == .current }) {
                    Section {
                        Button {
                            viewModel.useCurrentLocation()
                        } label: {
                            Label("Use Current Location", systemImage: "location.fill")
                                .padding(.vertical, 6)
                        }
                        .disabled(viewModel.isLoading)
                    } footer: {
                        Text("Automatically follows you as you travel.")
                    }
                }
            } else {
                Section("Search Results") {
                    if isSearching {
                        ProgressView("Searching…")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if let searchError {
                        Label(searchError, systemImage: "exclamationmark.magnifyingglass")
                            .foregroundStyle(.secondary)
                    } else if results.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No locations found").font(.headline)
                            Text("Try a city and state, or a ZIP code.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(results) { location in
                            let isSaved = viewModel.savedLocations.contains { $0.id == location.id }
                            Button {
                                Task {
                                    await viewModel.addLocation(location)
                                    query = ""
                                    onSelection()
                                }
                            } label: {
                                LocationSearchResultRow(location: location, isSaved: isSaved)
                            }
                            .disabled(viewModel.isLoading)
                        }
                    }
                }
            }

            if viewModel.isLoading {
                Section {
                    ProgressView("Loading weather…")
                }
            }
            if let message = viewModel.errorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        #elseif os(macOS)
        .listStyle(.inset)
        #endif
        #if os(iOS)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "City or ZIP Code")
        #else
        .searchable(text: $query, prompt: "City or ZIP Code")
        #endif
        .task(id: query) {
            await searchLocations()
        }
    }

    @MainActor
    private func searchLocations() async {
        results = []
        searchError = nil
        guard !trimmedQuery.isEmpty else {
            isSearching = false
            return
        }
        isSearching = true
        do {
            try await Task.sleep(for: .milliseconds(400))
            let matches = try await LocationSearchService.search(trimmedQuery)
            try Task.checkCancellation()
            results = matches
            isSearching = false
        } catch {
            guard !Task.isCancelled else { return }
            searchError = error.dewPointDisplayMessage
            isSearching = false
        }
    }
}

private struct SavedLocationRow: View {
    let location: DewPointLocation
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: location.mode == .current ? "location.fill" : "mappin.and.ellipse")
                .font(.title3)
                .foregroundStyle(.cyan)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(location.mode == .current ? "Current Location" : location.compactDisplayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if location.mode == .current {
                    Text(location.compactDisplayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Selected")
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

private struct LocationSearchResultRow: View {
    let location: DewPointLocation
    let isSaved: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(.cyan)
            Text(location.name)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Image(systemName: isSaved ? "checkmark.circle.fill" : "plus.circle.fill")
                .foregroundStyle(.tint)
                .accessibilityLabel(isSaved ? "Saved" : "Add location")
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
