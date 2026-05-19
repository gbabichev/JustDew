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
            .navigationTitle("JustDew")
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
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: reading.symbolName)
                            .foregroundStyle(.cyan)
                        Text(DewPointFormatters.temperature(reading.dewPoint))
                            .font(.system(size: displayTemperatureSize, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }

                    Label(reading.location.name, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Label(DewPointFormatters.temperature(reading.temperature), systemImage: "thermometer.medium")
                        Label(DewPointFormatters.percent(reading.humidity), systemImage: "humidity")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            } else {
                ContentUnavailableView("No Dew Point", systemImage: "drop.degreesign")
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

    private var locationSection: some View {
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

            Button {
                viewModel.refresh()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(viewModel.configuredLocation == nil)
        }
    }

    #if os(watchOS)
    private var watchContent: some View {
        NavigationStack {
            Form {
                dewPointSection
                locationSection
            }
            .navigationTitle("JustDew")
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
