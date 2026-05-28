import CoreLocation
import SwiftUI

struct DewPointAppView: View {
    @StateObject private var viewModel = DewPointViewModel()

    var body: some View {
        #if os(watchOS)
        watchContent
            .task {
                viewModel.loadInitialReading()
            }
        #else
        NavigationStack {
            Form {
                dewPointSection
                locationSection
            }
            .formStyle(.grouped)
            #if os(iOS)
            .refreshable {
                await viewModel.refreshNow()
            }
            .scrollDismissesKeyboard(.interactively)
            #endif
            #if os(macOS)
            .navigationTitle("JustDew")
            #endif
        }
        .task {
            viewModel.loadInitialReading()
        }
        #endif
    }

    private var dewPointSection: some View {
        Section("Dew Point") {
            if let reading = viewModel.reading {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Text(DewPointFormatters.temperature(reading.dewPoint))
                            .font(.system(size: displayTemperatureSize, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(DewPointComfortScale.color(for: reading.dewPointCelsius))

                        Spacer(minLength: 12)

                        Image(systemName: reading.symbolName)
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.cyan)
                            .padding(.top, 6)
                    }

                    Label(reading.location.compactDisplayName, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Label(DewPointFormatters.temperature(reading.temperature), systemImage: "thermometer.medium")
                        Label(DewPointFormatters.percent(reading.humidity), systemImage: "humidity")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    DewPointDayTimelineView(
                        reading: reading,
                        showsLabels: showsTimelineLabels,
                        trackHeight: timelineTrackHeight,
                        markerSize: timelineMarkerSize
                    )
                    .padding(.top, 2)

                    HStack(alignment: .center) {
                        Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Spacer(minLength: 12)

                        refreshControl
                    }

                    dewPointStatusContent
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 12) {
                    noDewPointContent
                    dewPointStatusContent
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var refreshControl: some View {
        if viewModel.isLoading {
            ProgressView()
                .controlSize(.small)
                .frame(width: 22, height: 22)
                .accessibilityLabel("Refreshing")
        } else {
            Button {
                viewModel.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .disabled(viewModel.configuredLocation == nil)
            .accessibilityLabel("Refresh")
        }
    }

    @ViewBuilder
    private var dewPointStatusContent: some View {
        if let errorMessage = viewModel.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var noDewPointContent: some View {
        #if os(watchOS)
        VStack(spacing: 6) {
            Image(systemName: "drop.degreesign")
                .font(.title3)
            Text("No Dew Point")
                .font(.headline)
        }
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, alignment: .center)
        #else
        ContentUnavailableView("No Dew Point", systemImage: "drop.degreesign")
        #endif
    }

    private var locationSection: some View {
        #if os(watchOS)
        Section("Location") {
            locationModePicker

            locationModeControls

//            if viewModel.configuredLocation != nil {
//                Button(role: .destructive) {
//                    viewModel.clearLocation()
//                } label: {
//                    Label("Clear Location", systemImage: "xmark.circle")
//                }
//                .disabled(viewModel.isLoading)
//            }

//            #if DEBUG
//            debugResetLocationButton
//            #endif
        }
        #else
        Section {
            VStack(alignment: .leading, spacing: 14) {
                locationModePicker
                locationModeControls

//                #if DEBUG
//                debugResetLocationButton
//                #endif
            }
            .padding(.vertical, 4)
        } header: {
            Text("Location")
        }
        #endif
    }

    private var locationModePicker: some View {
        #if os(watchOS)
        Picker("Source", selection: $viewModel.locationInputMode) {
            Text("Current Location").tag(DewPointLocationMode.current)
            Text("Search").tag(DewPointLocationMode.manual)
        }
        .onChange(of: viewModel.locationInputMode) { _, mode in
            startCurrentLocationIfSelected(mode)
        }
        #elseif os(macOS)
        VStack(alignment: .leading, spacing: 8) {
            Text("Location Source")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Location Source", selection: $viewModel.locationInputMode) {
                Text("Current Location").tag(DewPointLocationMode.current)
                Text("Search").tag(DewPointLocationMode.manual)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .onChange(of: viewModel.locationInputMode) { _, mode in
                startCurrentLocationIfSelected(mode)
            }
        }
        #else
        Picker("Location Source", selection: $viewModel.locationInputMode) {
            Text("Current Location").tag(DewPointLocationMode.current)
            Text("Search").tag(DewPointLocationMode.manual)
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.locationInputMode) { _, mode in
            startCurrentLocationIfSelected(mode)
        }
        #endif
    }

    private func startCurrentLocationIfSelected(_ mode: DewPointLocationMode) {
        guard mode == .current else { return }

        Task { @MainActor in
            await Task.yield()
            viewModel.useCurrentLocation()
        }
    }

    @ViewBuilder
    private var locationModeControls: some View {
        switch viewModel.locationInputMode {
        case .current:
            currentLocationControls
        case .manual:
            manualLocationControls
        }
    }

    @ViewBuilder
    private var currentLocationControls: some View {
        Group {
            if viewModel.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Finding location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .task {
            await Task.yield()
            viewModel.useCurrentLocationIfNeeded()
        }
    }

    private var manualLocationControls: some View {
        VStack(alignment: .leading, spacing: 8) {

            #if os(watchOS)
            TextField("City or Address", text: $viewModel.manualQuery)
                .onSubmit {
                    submitManualLocationIfPossible()
                }
                .submitLabel(.search)
                .lineLimit(1)
                .disabled(viewModel.isLoading)
            #else
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("City or ZIP Code", text: $viewModel.manualQuery)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        submitManualLocationIfPossible()
                    }
                    .submitLabel(.search)
                    .lineLimit(1)
                    .disabled(viewModel.isLoading)

                if !viewModel.manualQuery.isEmpty {
                    Button {
                        viewModel.manualQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Clear Search")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            #endif
        }
    }

    private func submitManualLocationIfPossible() {
        guard canSubmitManualLocation else { return }
        viewModel.useManualLocation()
    }

    private var canSubmitManualLocation: Bool {
        !viewModel.manualQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }

    #if DEBUG
    private var debugResetLocationButton: some View {
        Button(role: .destructive) {
            viewModel.debugResetLocationState()
        } label: {
            Label("Debug Reset Location", systemImage: "arrow.counterclockwise")
        }
        .disabled(viewModel.isLoading)
    }
    #endif

    #if os(watchOS)
    private var watchContent: some View {
        NavigationStack {
            Form {
                dewPointSection
                locationSection
            }
        }
    }
    #endif

    private var displayTemperatureSize: CGFloat {
        #if os(watchOS)
        30
        #else
        46
        #endif
    }

    private var showsTimelineLabels: Bool {
        #if os(watchOS)
        false
        #else
        true
        #endif
    }

    private var timelineTrackHeight: CGFloat {
        #if os(watchOS)
        5
        #else
        7
        #endif
    }

    private var timelineMarkerSize: CGFloat {
        #if os(watchOS)
        11
        #else
        14
        #endif
    }
}
