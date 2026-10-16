#if os(iOS) || os(macOS)
import SwiftUI

/// Choose from the window's available space, including split-screen and Duo poses.
struct DewPointAdaptiveAppView: View {
    @ObservedObject var viewModel: DewPointViewModel

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 760 {
                DewPointSplitView(viewModel: viewModel, showsSidebar: geometry.size.width >= 1_050)
            } else {
                #if os(macOS)
                MacDewPointAppView(viewModel: viewModel)
                #else
                DewPointIOSPagesView(viewModel: viewModel)
                #endif
            }
        }
        .task { viewModel.loadInitialReading() }
    }
}

private struct DewPointSplitView: View {
    @ObservedObject var viewModel: DewPointViewModel
    let showsSidebar: Bool
    @State private var columnVisibility: NavigationSplitViewVisibility

    init(viewModel: DewPointViewModel, showsSidebar: Bool) {
        self.viewModel = viewModel
        self.showsSidebar = showsSidebar
        _columnVisibility = State(initialValue: showsSidebar ? .all : .detailOnly)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            DewPointLocationsList(viewModel: viewModel, isSidebar: true)
                .navigationTitle("Locations")
                .navigationSplitViewColumnWidth(min: 230, ideal: 270, max: 320)
        } detail: {
            #if os(iOS)
            DewPointIOSPagesView(viewModel: viewModel, usesSidebar: true)
            #else
            NavigationStack {
                Group {
                    if let location = viewModel.configuredLocation {
                        DewPointLocationPage(viewModel: viewModel, location: location)
                    } else {
                        ContentUnavailableView("Choose a Location", systemImage: "mappin.and.ellipse",
                                               description: Text("Search for a city or choose a saved location in the sidebar."))
                    }
                }
                .navigationTitle(viewModel.configuredLocation?.compactDisplayName ?? "JustDew")
                .navigationSubtitle(viewModel.configuredLocation?.mode == .current ? Text("Current Location") : Text(""))
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewModel.refresh()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoading || viewModel.configuredLocation == nil)
                        .keyboardShortcut("r", modifiers: .command)
                    }
                }
            }
            #endif
        }
        #if os(iOS)
        .navigationSplitViewStyle(.prominentDetail)
        #else
        .navigationSplitViewStyle(.balanced)
        #endif
        .onChange(of: showsSidebar) { _, showsSidebar in
            columnVisibility = showsSidebar ? .all : .detailOnly
        }
    }
}

struct DewPointLocationsListStyle: ViewModifier {
    let isSidebar: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isSidebar {
            #if os(iOS)
            content
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .background(.regularMaterial, ignoresSafeAreaEdges: .all)
                .toolbarBackground(.hidden, for: .navigationBar)
                .scrollEdgeEffectStyle(.soft, for: .vertical)
            #else
            content.listStyle(.sidebar)
            #endif
        } else {
            #if os(macOS)
            content.listStyle(.inset)
            #else
            content.listStyle(.insetGrouped)
            #endif
        }
    }
}
#endif
