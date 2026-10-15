import SwiftUI

#if os(iOS) || os(macOS)
struct DewPointWelcomeHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "drop.degreesign.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.cyan)
                .padding(18)
                .background(.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
            Text("Welcome to JustDew")
                .font(.title2.weight(.semibold))
            Text("Choose a location to see its dew point, comfort level, and forecast.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#endif

#if os(iOS)
struct DewPointIOSWelcomeView: View {
    @ObservedObject var viewModel: DewPointViewModel
    let searchLocations: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    DewPointWelcomeHeader()
                    DewPointWelcomeActions(
                        isLoading: viewModel.isLoading,
                        useCurrentLocation: viewModel.useCurrentLocation,
                        searchLocations: searchLocations
                    )
                    if viewModel.isLoading {
                        ProgressView("Loading weather…")
                    }
                    if let message = viewModel.errorMessage {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: 420)
                .padding(24)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }
}

private struct DewPointWelcomeActions: View {
    let isLoading: Bool
    let useCurrentLocation: () -> Void
    let searchLocations: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Button(action: useCurrentLocation) {
                    Label("Use Current Location", systemImage: "location.fill")
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                Text("Follows your location as you travel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button(action: searchLocations) {
                Label("Search for a City", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .disabled(isLoading)
    }
}
#endif
