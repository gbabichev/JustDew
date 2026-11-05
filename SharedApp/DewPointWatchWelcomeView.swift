#if os(watchOS)
import SwiftUI

struct DewPointWatchWelcomeView: View {
    @ObservedObject var viewModel: DewPointViewModel
    let selectLocation: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "drop.degreesign.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                    .accessibilityHidden(true)
                Text("Choose a location for dew point and weather.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: viewModel.useCurrentLocation) {
                    Label("Current Location", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)

                Button(action: selectLocation) {
                    Label("Select Location", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)

                if viewModel.isLoading {
                    ProgressView("Loading weather…")
                        .font(.footnote)
                }
                if let message = viewModel.errorMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    if message == DewPointError.permissionDenied.localizedDescription {
                        Text("Allow location access in Settings on your Watch, or select a city.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
    }
}
#endif
