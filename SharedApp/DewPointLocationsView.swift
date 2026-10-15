import SwiftUI

struct DewPointAppView: View {
    @StateObject private var viewModel = DewPointViewModel()
    @State private var showsLocations = false

    var body: some View {
        #if os(macOS)
        DewPointAdaptiveAppView(viewModel: viewModel)
        #elseif os(iOS)
        DewPointAdaptiveAppView(viewModel: viewModel)
        #else
        NavigationStack {
            Group {
                if viewModel.savedLocations.isEmpty {
                    DewPointLocationsList(viewModel: viewModel)
                } else if let location = viewModel.configuredLocation {
                    DewPointLocationPage(viewModel: viewModel, location: location)
                }
            }
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
            // Quickboard needs to present text entry without a modal sheet in flight.
            .navigationDestination(isPresented: $showsLocations) {
                DewPointLocationsList(viewModel: viewModel, onSelection: { showsLocations = false })
                    .navigationTitle("Locations")
            }
        }
        .task { viewModel.loadInitialReading() }
        #endif
    }
}

#if os(iOS)
struct DewPointIOSPagesView: View {
    @ObservedObject var viewModel: DewPointViewModel
    let usesSidebar: Bool
    @State private var showsLocations = false
    @State private var selectedID: String?
    @State private var pageLocations: [DewPointLocation]
    @State private var isLocationSheetActive = false

    init(viewModel: DewPointViewModel, usesSidebar: Bool = false) {
        self.viewModel = viewModel
        self.usesSidebar = usesSidebar
        _pageLocations = State(initialValue: viewModel.savedLocations)
        _selectedID = State(initialValue: viewModel.configuredLocation?.id)
    }

    var body: some View {
        Group {
            if pageLocations.isEmpty {
                NavigationStack {
                    DewPointIOSWelcomeView(viewModel: viewModel) {
                        isLocationSheetActive = true
                        showsLocations = true
                    }
                    .navigationBarTitleDisplayMode(.inline)
                }
                .id("location-setup")
            } else {
                // Keep one navigation container at the display edge so its
                // toolbar can adapt independently of the sliding weather pages.
                NavigationStack {
                    ScrollView {
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 0) {
                                ForEach(pageLocations) { location in
                                    DewPointLocationPage(viewModel: viewModel, location: location, scrollsVertically: false)
                                        .containerRelativeFrame(.horizontal)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .id(location.id)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.paging)
                        .scrollPosition(id: $selectedID)
                        .scrollIndicators(.hidden)
                        .contentMargins(.horizontal, 0, for: .scrollContent)
                        .fixedSize(horizontal: false, vertical: true)
                        .clipped()
                    }
                    .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
                    .scrollEdgeEffectStyle(.soft, for: .top)
                    .refreshable { await viewModel.refreshNow() }
                    .allowsHitTesting(!viewModel.isLoading)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        DewPointPageControl(locationIDs: pageLocations.map(\.id), selectedID: $selectedID)
                            .disabled(viewModel.isLoading)
                            .padding(.vertical, 6)
                    }
                    .navigationTitle(displayedLocation?.compactDisplayName ?? "JustDew")
                    .navigationSubtitle(displayedLocation?.mode == .current ? Text("Current Location") : Text(""))
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        if usesSidebar {
                            ToolbarItem(placement: .primaryAction) {
                                Button {
                                    viewModel.refresh()
                                } label: {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                }
                                .disabled(viewModel.isLoading || viewModel.configuredLocation == nil)
                                .keyboardShortcut("r", modifiers: .command)
                            }
                        } else {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    isLocationSheetActive = true
                                    showsLocations = true
                                } label: {
                                    Label("Locations", systemImage: "list.bullet")
                                }
                            }
                        }
                    }
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .sheet(isPresented: $showsLocations, onDismiss: {
            isLocationSheetActive = false
            synchronizePages()
        }) {
            NavigationStack {
                DewPointLocationsList(viewModel: viewModel, onSelection: { showsLocations = false })
                    .navigationTitle("Locations")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showsLocations = false }
                        }
                    }
            }
        }
        .onChange(of: selectedID) { _, id in
            guard !isLocationSheetActive, let id,
                  id != viewModel.configuredLocation?.id,
                  let location = viewModel.savedLocations.first(where: { $0.id == id }) else { return }
            viewModel.selectLocation(location)
        }
        .onChange(of: viewModel.configuredLocation?.id) { _, _ in synchronizePages() }
        .onChange(of: viewModel.savedLocations) { _, _ in synchronizePages() }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            if !isLoading { synchronizePages() }
        }
    }

    private var displayedLocation: DewPointLocation? {
        pageLocations.first(where: { $0.id == selectedID }) ?? pageLocations.first
    }

    private func synchronizePages() {
        // Keep page membership stable while the location sheet and keyboard
        // dismiss, then apply the saved locations and selection together.
        guard !isLocationSheetActive, !viewModel.isLoading else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            pageLocations = viewModel.savedLocations
            selectedID = viewModel.configuredLocation?.id
        }
    }
}

#endif

struct DewPointLocationsList: View {
    @ObservedObject var viewModel: DewPointViewModel
    var onSelection: () -> Void = {}
    var isSidebar = false
    @State private var query = ""
    @State private var search = LocationAutocomplete()

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List(selection: sidebarSelection) {
            if trimmedQuery.isEmpty {
                Section {
                    ForEach(viewModel.savedLocations) { location in
                        Button {
                            if !isSidebar || viewModel.configuredLocation?.id != location.id {
                                viewModel.selectLocation(location)
                            }
                            onSelection()
                        } label: {
                            #if os(macOS)
                            if isSidebar {
                                SidebarLocationRow(location: location, reading: cachedReading(for: location))
                            } else {
                                SavedLocationRow(location: location,
                                                 isSelected: viewModel.configuredLocation?.id == location.id)
                            }
                            #elseif os(iOS)
                            if isSidebar {
                                SidebarLocationRow(location: location, reading: cachedReading(for: location))
                            } else {
                                SavedLocationRow(location: location,
                                                 isSelected: viewModel.configuredLocation?.id == location.id)
                            }
                            #else
                            SavedLocationRow(location: location,
                                             isSelected: viewModel.configuredLocation?.id == location.id)
                            #endif
                        }
                        .disabled(viewModel.isLoading)
                        .tag(location.id)
                        #if os(iOS)
                        .listRowBackground(isSidebar
                            ? RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(viewModel.configuredLocation?.id == location.id
                                    ? Color.accentColor.opacity(0.12) : Color.clear)
                            : nil)
                        .accessibilityAddTraits(viewModel.configuredLocation?.id == location.id ? .isSelected : [])
                        #endif
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
                    if search.isSearching {
                        ProgressView("Searching…")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if let searchError = search.errorMessage {
                        Label(searchError, systemImage: "exclamationmark.magnifyingglass")
                            .foregroundStyle(.secondary)
                    } else if search.results.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No locations found").font(.headline)
                            Text("Try a city and state, or a ZIP code.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(search.results) { suggestion in
                            Button {
                                Task {
                                    if await viewModel.addLocation(suggestion) {
                                        query = ""
                                        onSelection()
                                    }
                                }
                            } label: {
                                LocationSearchResultRow(title: suggestion.title, subtitle: suggestion.subtitle)
                            }
                            .disabled(viewModel.isLoading)
                        }
                    }
                }
            }

            if viewModel.isLoading {
                Section {
                    ProgressView("Loading weather…")
                        .frame(maxWidth: .infinity, alignment: .center)
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
        .modifier(DewPointLocationsListStyle(isSidebar: isSidebar))
        .scrollDismissesKeyboard(.interactively)
        #elseif os(macOS)
        .modifier(DewPointLocationsListStyle(isSidebar: isSidebar))
        .buttonStyle(.plain)
        #endif
        #if os(iOS)
        .searchable(text: $query, placement: isSidebar ? .automatic : .navigationBarDrawer(displayMode: .always), prompt: "City or ZIP Code")
        #else
        .searchable(text: $query, prompt: "City or ZIP Code")
        #endif
        .onChange(of: query) { _, value in
            search.updateQuery(value)
        }
        .onAppear { search.updateQuery(query) }
        .onDisappear { search.cancel() }
    }

    private var sidebarSelection: Binding<String?>? {
        #if os(macOS)
        guard isSidebar else { return nil }
        return Binding(
            get: { viewModel.configuredLocation?.id },
            set: { id in
                guard !viewModel.isLoading, let id,
                      id != viewModel.configuredLocation?.id,
                      let location = viewModel.savedLocations.first(where: { $0.id == id }) else { return }
                viewModel.selectLocation(location)
                onSelection()
            }
        )
        #else
        nil
        #endif
    }

    private func cachedReading(for location: DewPointLocation) -> DewPointReading? {
        if viewModel.configuredLocation?.id == location.id { return viewModel.reading }
        return DewPointStore().loadReading(for: location)
    }
}

#if os(iOS) || os(macOS)
private struct SidebarLocationRow: View {
    let location: DewPointLocation
    let reading: DewPointReading?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(location.compactDisplayName)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if location.mode == .current {
                    Label("Current Location", systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let reading {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: reading.symbolName)
                            .font(.caption)
                            .symbolRenderingMode(.multicolor)
                            .accessibilityHidden(true)
                        Text(DewPointFormatters.temperature(reading.temperature))
                            .font(.system(.title3, design: .rounded, weight: .medium))
                            .monospacedDigit()
                            .accessibilityLabel("Temperature \(DewPointFormatters.temperature(reading.temperature))")
                    }
                    Text("Dew point \(DewPointFormatters.temperature(reading.dewPoint))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(DewPointComfortScale.color(for: reading.dewPointCelsius))
                }
                .fixedSize()
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
#endif

private struct SavedLocationRow: View {
    let location: DewPointLocation
    let isSelected: Bool
    var reading: DewPointReading? = nil

    var body: some View {
        #if os(watchOS)
        WatchSavedLocationRow(location: location, isSelected: isSelected)
        #else
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
            if let reading {
                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .fixedSize()
                    .foregroundStyle(DewPointComfortScale.color(for: reading.dewPointCelsius))
                    .accessibilityLabel("Dew point \(DewPointFormatters.temperature(reading.dewPoint))")
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Selected")
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        #endif
    }
}

private struct LocationSearchResultRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        #if os(watchOS)
        WatchLocationSearchResultRow(title: title, subtitle: subtitle)
        #else
        HStack(spacing: 14) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).foregroundStyle(.primary)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
                .accessibilityLabel("Add location")
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        #endif
    }
}

#if os(watchOS)
private struct WatchSavedLocationRow: View {
    let location: DewPointLocation
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if location.mode == .current {
                HStack(spacing: 5) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.cyan)
                    Text("Current Location")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Selected")
                    }
                }
                .font(.caption2)
                Text(location.compactDisplayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                    Text(location.compactDisplayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Selected")
                    }
                }
            }
        }
        .multilineTextAlignment(.leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
#endif

#if os(watchOS)
private struct WatchLocationSearchResultRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.cyan)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Add location")
            }
            .font(.caption2)
        }
        .multilineTextAlignment(.leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
#endif
