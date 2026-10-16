import SwiftUI
import WidgetKit

struct DewPointAppView: View {
    @StateObject private var viewModel = DewPointViewModel()
    @State private var showsLocations = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var temperatureUnitSymbol = UnitTemperature(forLocale: .autoupdatingCurrent, usage: .weather).symbol

    var body: some View {
        Group {
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
        // Temperature labels are preformatted strings. Recreate their views
        // only when the system unit changes; the view model keeps the selected location.
        .id(temperatureUnitSymbol)
        .onChange(of: scenePhase) { _, phase in
            DewPointStartupLog.event("scene.phase", "phase=\(phase) configured=\(DewPointStartupLog.location(viewModel.configuredLocation))")
            if phase == .active {
                updateTemperaturePreference()
                viewModel.loadInitialReading()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
            updateTemperaturePreference()
        }
    }

    private func updateTemperaturePreference() {
        let symbol = UnitTemperature(forLocale: .autoupdatingCurrent, usage: .weather).symbol
        guard symbol != temperatureUnitSymbol else { return }
        temperatureUnitSymbol = symbol
        WidgetCenter.shared.reloadAllTimelines()
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
                    DewPointHingeAwarePager(viewModel: viewModel, locations: pageLocations, selectedID: $selectedID)
                    .navigationTitle(displayedLocation?.compactDisplayName ?? "JustDew")
                    .navigationSubtitle(displayedLocation?.mode == .current ? Text("Current Location") : Text(""))
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar {
                        if !usesSidebar {
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
            DewPointStartupLog.event("locationsSheet.dismiss", "selected=\(DewPointStartupLog.selection(selectedID, in: pageLocations)) configured=\(DewPointStartupLog.location(viewModel.configuredLocation))")
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
        .onAppear {
            DewPointStartupLog.event("pages.appear", "selected=\(DewPointStartupLog.selection(selectedID, in: pageLocations)) title=\(DewPointStartupLog.location(displayedLocation)) configured=\(DewPointStartupLog.location(viewModel.configuredLocation)) loading=\(viewModel.isLoading)")
        }
        .onChange(of: selectedID) { oldID, id in
            DewPointStartupLog.event("pages.selection", "old=\(DewPointStartupLog.selection(oldID, in: pageLocations)) new=\(DewPointStartupLog.selection(id, in: pageLocations)) configured=\(DewPointStartupLog.location(viewModel.configuredLocation)) sheetActive=\(isLocationSheetActive) loading=\(viewModel.isLoading)")
            guard !isLocationSheetActive, let id,
                  id != viewModel.configuredLocation?.id,
                  let location = viewModel.savedLocations.first(where: { $0.id == id }) else { return }
            viewModel.selectLocation(location)
        }
        .onChange(of: viewModel.configuredLocation?.id) { _, _ in synchronizePages() }
        .onChange(of: viewModel.savedLocations) { _, _ in synchronizePages() }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            DewPointStartupLog.event("pages.loading", "loading=\(isLoading) selected=\(DewPointStartupLog.selection(selectedID, in: pageLocations)) configured=\(DewPointStartupLog.location(viewModel.configuredLocation))")
            if !isLoading { synchronizePages() }
        }
    }

    private var displayedLocation: DewPointLocation? {
        pageLocations.first(where: { $0.id == selectedID }) ?? pageLocations.first
    }

    private func synchronizePages() {
        // Keep page membership stable while the location sheet and keyboard
        // dismiss, then apply the saved locations and selection together.
        DewPointStartupLog.event("pages.synchronize", "selected=\(DewPointStartupLog.selection(selectedID, in: pageLocations)) configured=\(DewPointStartupLog.location(viewModel.configuredLocation)) deferred=\(isLocationSheetActive || viewModel.isLoading) pages=[\(DewPointStartupLog.pages(viewModel.savedLocations))]")
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
    var onSearchQueryChange: (String) -> Void = { _ in }
    @State private var query = ""
    @State private var search = LocationAutocomplete()
    @State private var selectedSidebarLocationID: String?

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List(selection: sidebarSelection) {
            if trimmedQuery.isEmpty {
                Section {
                    ForEach(viewModel.savedLocations) { location in
                        Button {
                            #if os(macOS)
                            if isSidebar {
                                selectedSidebarLocationID = location.id
                            } else {
                                viewModel.selectLocation(location)
                                onSelection()
                            }
                            #else
                            if !isSidebar || viewModel.configuredLocation?.id != location.id {
                                viewModel.selectLocation(location)
                            }
                            onSelection()
                            #endif
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
            onSearchQueryChange(value)
        }
        .onChange(of: selectedSidebarLocationID) { _, id in
            #if os(macOS)
            guard isSidebar, !viewModel.isLoading, let id,
                  id != viewModel.configuredLocation?.id,
                  let location = viewModel.savedLocations.first(where: { $0.id == id }) else { return }
            viewModel.selectLocation(location)
            onSelection()
            #endif
        }
        .onChange(of: viewModel.configuredLocation?.id) { _, id in
            if isSidebar { selectedSidebarLocationID = id }
        }
        .onAppear {
            search.updateQuery(query)
            if isSidebar { selectedSidebarLocationID = viewModel.configuredLocation?.id }
        }
        .onDisappear { search.cancel() }
    }

    private var sidebarSelection: Binding<String?>? {
        #if os(macOS)
        guard isSidebar else { return nil }
        return Binding(
            get: { selectedSidebarLocationID },
            set: { id in
                guard !viewModel.isLoading else { return }
                selectedSidebarLocationID = id
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
        #if os(iOS)
        IOSSidebarLocationRow(location: location, reading: reading)
        #else
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
        #endif
    }
}

#if os(iOS)
private struct IOSSidebarLocationRow: View {
    let location: DewPointLocation
    let reading: DewPointReading?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Give the name the row's full width instead of competing with two readings.
            Text(location.compactDisplayName)
                .font(.body.weight(.medium))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .truncationMode(.tail)
            if location.mode == .current {
                Label("Current Location", systemImage: "location.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            }
            if let reading {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        SidebarDewPointValue(reading: reading)
                        Spacer(minLength: 0)
                        SidebarWeatherValue(reading: reading)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        SidebarDewPointValue(reading: reading)
                        SidebarWeatherValue(reading: reading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private struct SidebarDewPointValue: View {
    let reading: DewPointReading

    var body: some View {
        Text("Dew point \(DewPointFormatters.temperature(reading.dewPoint))")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(DewPointComfortScale.color(for: reading.dewPointCelsius))
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct SidebarWeatherValue: View {
    let reading: DewPointReading

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: reading.symbolName)
                .symbolRenderingMode(.multicolor)
                .accessibilityHidden(true)
            Text(DewPointFormatters.temperature(reading.temperature))
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Temperature \(DewPointFormatters.temperature(reading.temperature))")
    }
}
#endif
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
