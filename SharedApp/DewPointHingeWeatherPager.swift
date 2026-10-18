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
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        GeometryReader { safeGeometry in
            let edges = reclaimedEdges(in: safeGeometry)
            GeometryReader { geometry in
                Group {
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
            }
            .ignoresSafeArea(.container, edges: edges)
        }
        .onHingeChange { _, context in
            hingeStatus = context.hinge?.status
        }
    }

    private func reclaimedEdges(in geometry: GeometryProxy) -> Edge.Set {
        guard let hingeStatus else { return [] }
        let isOuterDisplay = hingeStatus == .closed
        let isInnerLandscape = geometry.size.width > geometry.size.height
            && (hingeStatus == .fullyOpen || hingeStatus == .partiallyOpen)
            && !geometry.reservedRegions(kind: .division, options: .includeInactive).isEmpty
        guard isOuterDisplay || isInnerLandscape else { return [] }
        // Duo's controls remain on the physical right, including in RTL layouts.
        // Only extend the controls edge; do not ignore both horizontal insets.
        if layoutDirection == .leftToRight {
            return geometry.safeAreaInsets.trailing > 0 ? .trailing : []
        }
        return geometry.safeAreaInsets.leading > 0 ? .leading : []
    }

    private var displayedReading: DewPointReading? {
        guard let location = locations.first(where: { $0.id == selectedID }) ?? locations.first else { return nil }
        return viewModel.cachedReading(for: location)
    }
}

private struct DewPointWeatherPager: View {
    @ObservedObject var viewModel: DewPointViewModel
    let locations: [DewPointLocation]
    @Binding var selectedID: String?

    @State private var restoredLayout: PagerLayout?

    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
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
                .scrollPosition(id: $selectedID, anchor: .leading)
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, 0, for: .scrollContent)
                .fixedSize(horizontal: false, vertical: true)
                .clipped()
                .onScrollGeometryChange(for: PagerLayout.self) { geometry in
                    PagerLayout(viewportWidth: geometry.containerSize.width,
                                contentWidth: geometry.contentSize.width)
                } action: { _, layout in
                    // Startup first reports an empty, provisional layout. Scroll
                    // only once all page frames exist, and re-align after resizing.
                    guard layout.viewportWidth > 0,
                          abs(layout.contentWidth - layout.viewportWidth * CGFloat(locations.count)) < 1,
                          restoredLayout != layout,
                          let target = selectedID,
                          locations.contains(where: { $0.id == target }) else { return }
                    restoredLayout = layout
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        proxy.scrollTo(target, anchor: .leading)
                    }
                }
            }
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

private struct PagerLayout: Equatable {
    let viewportWidth: CGFloat
    let contentWidth: CGFloat
}

#endif
