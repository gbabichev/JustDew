#if os(macOS)
import SwiftUI

struct MacDewPointAppView: View {
    @ObservedObject var viewModel: DewPointViewModel
    @State private var showsLocations = false

    var body: some View {
        NavigationStack {
            Group {
                if let location = viewModel.configuredLocation {
                    DewPointLocationPage(viewModel: viewModel, location: location)
                } else {
                    ScrollView {
                        VStack(spacing: 28) {
                            MacDewPointWelcomeView()
                            MacLocationPicker(viewModel: viewModel)
                        }
                        .padding(24)
                        .padding(.top, 24)
                    }
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle(viewModel.configuredLocation?.compactDisplayName ?? "JustDew")
            .navigationSubtitle(viewModel.configuredLocation?.mode == .current ? Text("Current Location") : Text(""))
            .toolbar {
                if !viewModel.savedLocations.isEmpty {
                    ToolbarSpacer(.flexible, placement: .automatic)
                    ToolbarItemGroup(placement: .automatic) {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 20, height: 20)
                                .accessibilityLabel("Refreshing")
                        } else {
                            Button {
                                viewModel.refresh()
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .disabled(viewModel.configuredLocation == nil)
                            .keyboardShortcut("r", modifiers: .command)
                            .help("Refresh weather")
                        }
                        Button {
                            showsLocations = true
                        } label: {
                            Label("Locations", systemImage: "list.bullet")
                        }
                        .help("Manage saved locations")
                    }
                }
            }
            .sheet(isPresented: $showsLocations) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Locations").font(.title2.weight(.semibold))
                        Spacer()
                        Button("Done") { showsLocations = false }
                            .keyboardShortcut(.defaultAction)
                    }
                    .padding(20)
                    Divider()
                    ScrollView {
                        MacLocationPicker(viewModel: viewModel, onSelection: { showsLocations = false })
                            .padding(20)
                    }
                }
                .frame(width: 400, height: 520)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
    }
}

private struct MacDewPointWelcomeView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "drop.degreesign.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.cyan)
                .padding(18)
                .background(.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
            Text("Welcome to JustDew")
                .font(.title2.weight(.semibold))
            Text("Choose a location to see its dew point,\ncomfort level, and forecast.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MacLocationPicker: View {
    @ObservedObject var viewModel: DewPointViewModel
    var onSelection: () -> Void = {}
    @State private var query = ""
    @State private var search = LocationAutocomplete()

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            MacLocationSearchField(query: $query)

            if trimmedQuery.isEmpty {
                if !viewModel.savedLocations.isEmpty {
                    Text("Saved Locations")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.savedLocations) { location in
                        MacSavedLocationRow(
                            location: location,
                            isSelected: viewModel.configuredLocation?.id == location.id,
                            select: {
                                viewModel.selectLocation(location)
                                onSelection()
                            },
                            remove: { viewModel.removeLocation(id: location.id) }
                        )
                        .disabled(viewModel.isLoading)
                    }
                }
                if !viewModel.savedLocations.contains(where: { $0.mode == .current }) {
                    VStack(spacing: 8) {
                        Button {
                            viewModel.useCurrentLocation()
                        } label: {
                            Label("Use Current Location", systemImage: "location.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(viewModel.isLoading)
                        Text("Follows your location as you travel.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else if search.isSearching {
                ProgressView("Searching…")
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if let searchError = search.errorMessage {
                Label(searchError, systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if search.results.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No locations found").font(.headline)
                    Text("Try a city and state, or a ZIP code.")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .padding(.vertical, 8)
            } else {
                Text("Search Results")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(search.results) { suggestion in
                    Button {
                        Task {
                            if await viewModel.addLocation(suggestion) {
                                query = ""
                                onSelection()
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse").foregroundStyle(.cyan)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.title).foregroundStyle(.primary)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.tint)
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoading)
                }
            }

            if viewModel.isLoading {
                ProgressView("Loading weather…")
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            }
            if let message = viewModel.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .onChange(of: query, initial: true) { _, value in
            search.updateQuery(value)
        }
        .onDisappear { search.cancel() }
    }
}

private struct MacLocationSearchField: View {
    @Binding var query: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("City or ZIP code", text: $query)
                .textFieldStyle(.plain)
                .accessibilityLabel("Search locations")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.1), lineWidth: 1)
        }
    }
}

private struct MacSavedLocationRow: View {
    let location: DewPointLocation
    let isSelected: Bool
    let select: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: select) {
                HStack(spacing: 10) {
                    Image(systemName: location.mode == .current ? "location.fill" : "mappin.and.ellipse")
                        .foregroundStyle(.cyan)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(location.mode == .current ? "Current Location" : location.compactDisplayName)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        if location.mode == .current {
                            Text(location.compactDisplayName)
                                .font(.caption)
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button(role: .destructive, action: remove) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("Remove location")
            .accessibilityLabel("Remove \(location.compactDisplayName)")
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        }
    }
}
#endif
