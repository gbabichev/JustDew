import CoreLocation
import SwiftUI

struct DewPointLocationPage: View {
    @ObservedObject var viewModel: DewPointViewModel
    let location: DewPointLocation
    var scrollsVertically = true

    private var displayedReading: DewPointReading? {
        if viewModel.configuredLocation?.id == location.id { return viewModel.reading }
        return DewPointStore().loadReading(for: location)
    }

    var body: some View {
        #if os(watchOS)
        WatchWeatherDashboard(
            reading: displayedReading,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            refresh: { [viewModel] in await viewModel.refreshNow() }
        )
        #else
        if scrollsVertically {
            DewPointWeatherScrollView(
                reading: displayedReading,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                refresh: { [viewModel] in await viewModel.refreshNow() }
            )
            #if DEBUG
            .modifier(DewPointPageContentTrace(page: location, reading: displayedReading,
                source: viewModel.configuredLocation?.id == location.id ? "viewModel" : "cache"))
            #endif
        } else {
            DewPointWeatherContent(
                reading: displayedReading,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage
            )
            #if DEBUG
            .modifier(DewPointPageContentTrace(page: location, reading: displayedReading,
                source: viewModel.configuredLocation?.id == location.id ? "viewModel" : "cache"))
            #endif
        }
        #endif
    }

}
