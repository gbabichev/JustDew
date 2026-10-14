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
                    DewPointLocationsList(viewModel: viewModel)
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

    var body: some View {
        Form {
            Section("Saved Locations") {
                ForEach(viewModel.savedLocations) { location in
                    Button {
                        viewModel.selectLocation(location)
                    } label: {
                        HStack {
                            Label(location.mode == .current ? "Current Location" : location.compactDisplayName,
                                  systemImage: location.mode == .current ? "location.fill" : "mappin.and.ellipse")
                            Spacer()
                            if viewModel.configuredLocation?.id == location.id {
                                Image(systemName: "checkmark")
                            }
                        }
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
            }
            Section("Add Location") {
                Button {
                    viewModel.useCurrentLocation()
                } label: {
                    Label("Use Current Location", systemImage: "location.fill")
                }
                .disabled(viewModel.isLoading)

                TextField("City or ZIP Code", text: $viewModel.manualQuery)
                    .onSubmit { addLocation() }
                    .submitLabel(.search)
                    .disabled(viewModel.isLoading)
                Button("Add Location", action: addLocation)
                    .disabled(viewModel.isLoading || viewModel.manualQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if viewModel.isLoading {
                    ProgressView("Loading weather…")
                }
                if let message = viewModel.errorMessage {
                    Text(message).foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func addLocation() {
        guard !viewModel.manualQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        viewModel.useManualLocation()
    }
}
