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
        Form {
            dewPointSection
            forecastSection
        }
        .formStyle(.grouped)
        .refreshable { await viewModel.refreshNow() }
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

    #if os(watchOS)
    private var dewPointSection: some View {
        Section {
            if let reading = displayedReading {
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

                    #if os(watchOS)
                    Label(reading.location.compactDisplayName, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    #endif

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
        } header: {
            #if os(watchOS)
            Text("Dew Point")
            #else
            DewPointLocationHeading(location: location)
                .textCase(nil)
            #endif
        }
    }

    @ViewBuilder
    private var forecastSection: some View {
        if let reading = displayedReading, hasFutureForecast(reading) {
            Section("Forecast") {
                DewPointForecastView(
                    reading: reading,
                    trackHeight: weeklyForecastTrackHeight
                )
                .padding(.vertical, 2)

                weatherAttributionContent
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

    private var weatherAttributionContent: some View {
        Link("Data from \(DewPointConfiguration.appleWeatherTrademark)", destination: DewPointConfiguration.appleWeatherLegalAttributionURL)
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityLabel("Weather data from \(DewPointConfiguration.appleWeatherTrademark). Opens legal attribution.")
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

    private func hasFutureForecast(_ reading: DewPointReading) -> Bool {
        let calendar = reading.forecastCalendar
        let todayStart = calendar.startOfDay(for: reading.observedAt)
        guard let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) else { return false }

        return reading.dailyForecastPoints.contains { $0.date >= tomorrowStart }
    }

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

    private var weeklyForecastTrackHeight: CGFloat {
        #if os(watchOS)
        5
        #else
        7
        #endif
    }
    #endif
}
