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

                    HStack(alignment: .center) {
                        Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Spacer(minLength: 12)

                        Button {
                            viewModel.refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .controlSize(.small)
                        .disabled(viewModel.configuredLocation == nil || viewModel.isLoading)
                        .accessibilityLabel("Refresh")
                    }
                }
                .padding(.vertical, 4)
            } else {
                noDewPointContent
            }

            if viewModel.isLoading {
                ProgressView()
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
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
            Button {
                viewModel.useCurrentLocation()
            } label: {
                Label("Current Location", systemImage: "location.fill")
            }

            HStack {
                TextField("City or Address", text: $viewModel.manualQuery)
                    #if !os(watchOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
                    .onSubmit {
                        viewModel.useManualLocation()
                    }

                Button {
                    viewModel.useManualLocation()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .disabled(viewModel.manualQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Set Manual Location")
            }

            if viewModel.configuredLocation != nil || !viewModel.manualQuery.isEmpty {
                Button {
                    viewModel.clearLocation()
                } label: {
                    Label("Clear Location", systemImage: "xmark.circle.fill")
                }
            }
        }
        #else
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    viewModel.useCurrentLocation()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill")
                            .font(.headline)
                            .foregroundStyle(.tint)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Location")
                                .font(.body.weight(.medium))

                            if viewModel.configuredLocation?.mode == .current,
                               let locationName = viewModel.configuredLocation?.compactDisplayName {
                                Text(locationName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 12)

                        if viewModel.configuredLocation?.mode == .current {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    TextField("City or Address", text: $viewModel.manualQuery)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            viewModel.useManualLocation()
                        }

                    if viewModel.configuredLocation != nil || !viewModel.manualQuery.isEmpty {
                        Button {
                            viewModel.clearLocation()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(viewModel.isLoading)
                        .accessibilityLabel("Clear Location")
                    }

                    Button {
                        viewModel.useManualLocation()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.manualQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isLoading)
                    .accessibilityLabel("Set Manual Location")
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Location")
        }
        #endif
    }

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
}
