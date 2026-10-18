import CoreLocation
import SwiftUI

struct DewPointLocationPage: View {
    @ObservedObject var viewModel: DewPointViewModel
    let location: DewPointLocation
    var scrollsVertically = true

    private var displayedReading: DewPointReading? {
        viewModel.cachedReading(for: location)
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
        } else {
            DewPointWeatherContent(
                reading: displayedReading,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage
            )
        }
        #endif
    }

}
