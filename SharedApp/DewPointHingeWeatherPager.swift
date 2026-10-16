#if os(iOS)
import SwiftUI

struct DewPointHingeAwarePager: View {
    @ObservedObject var viewModel: DewPointViewModel
    let locations: [DewPointLocation]
    @Binding var selectedID: String?

    var body: some View {
        Group {
            if #available(iOS 27.1, *) {
                DewPointHingeResponsivePager(viewModel: viewModel, locations: locations, selectedID: $selectedID)
            } else {
                DewPointWeatherPager(viewModel: viewModel, locations: locations, selectedID: $selectedID)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .allowsHitTesting(!viewModel.isLoading)
    }
}

@available(iOS 27.1, *)
private struct DewPointHingeResponsivePager: View {
    @ObservedObject var viewModel: DewPointViewModel
    let locations: [DewPointLocation]
    @Binding var selectedID: String?
    @State private var hingeStatus: DeviceHinge.Status?

    var body: some View {
        GeometryReader { geometry in
            let division = geometry.reservedRegions(kind: .division).first
            // Active geometry also protects the initial frame before the hinge callback arrives.
            if let division, hingeStatus == nil || hingeStatus == .partiallyOpen {
                DewPointFoldedWeatherDashboard(
                    reading: displayedReading,
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage,
                    axis: division.frame.height >= division.frame.width ? .horizontal : .vertical,
                    locations: locations,
                    selectedID: $selectedID,
                    refresh: { [viewModel] in await viewModel.refreshNow() }
                )
            } else {
                DewPointWeatherPager(viewModel: viewModel, locations: locations, selectedID: $selectedID)
                    .environment(\.weatherDashboardViewport, geometry.size)
            }
        }
        .onHingeChange { _, context in
            hingeStatus = context.hinge?.status
        }
    }

    private var displayedReading: DewPointReading? {
        guard let location = locations.first(where: { $0.id == selectedID }) ?? locations.first else { return nil }
        return viewModel.configuredLocation?.id == location.id
            ? viewModel.reading : DewPointStore().loadReading(for: location)
    }
}

private struct DewPointWeatherPager: View {
    @ObservedObject var viewModel: DewPointViewModel
    let locations: [DewPointLocation]
    @Binding var selectedID: String?

    var body: some View {
        ScrollView {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(locations) { location in
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
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable { await viewModel.refreshNow() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DewPointPageControl(locationIDs: locations.map(\.id), selectedID: $selectedID)
                .disabled(viewModel.isLoading)
                .padding(.vertical, 6)
        }
    }
}
#endif
