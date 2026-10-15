#if os(iOS) || os(macOS)
import SwiftUI

struct DewPointWeatherScrollView: View {
    let reading: DewPointReading?
    let isLoading: Bool
    let errorMessage: String?
    let refresh: @MainActor @Sendable () async -> Void

    var body: some View {
        ScrollView {
            DewPointWeatherContent(reading: reading, isLoading: isLoading, errorMessage: errorMessage)
        }
        .background {
            #if os(iOS)
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            #else
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            #endif
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable { await refresh() }
    }
}

struct DewPointWeatherContent: View {
    let reading: DewPointReading?
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            if let reading, reading.hasFutureForecast {
                HStack(alignment: .top, spacing: 24) {
                    DewPointCurrentSection(reading: reading, isLoading: isLoading, errorMessage: errorMessage)
                        .frame(minWidth: 310, maxWidth: .infinity)
                    DewPointForecastSection(reading: reading)
                        .frame(minWidth: 310, maxWidth: .infinity)
                }
                .frame(minWidth: 700)
            }
            VStack(alignment: .leading, spacing: 24) {
                DewPointCurrentSection(reading: reading, isLoading: isLoading, errorMessage: errorMessage)
                if let reading {
                    DewPointForecastSection(reading: reading)
                }
            }
        }
        .frame(maxWidth: 1_100, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(20)
        // Leave room for the iOS page indicator without changing the viewport.
        .padding(.bottom, 24)
    }
}

private struct DewPointCurrentSection: View {
    let reading: DewPointReading?
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Dew Point")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            DewPointWeatherCard {
                if let reading {
                    DewPointCurrentWeatherView(reading: reading, errorMessage: errorMessage)
                } else {
                    VStack(spacing: 12) {
                        if isLoading {
                            ProgressView("Loading weather…")
                                .frame(maxWidth: .infinity)
                        } else {
                            ContentUnavailableView("No Dew Point", systemImage: "drop.degreesign")
                        }
                        DewPointWeatherErrorView(message: errorMessage)
                    }
                }
            }
        }
    }
}

private struct DewPointWeatherCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    #if os(iOS)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    #else
                    .fill(Color.primary.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    }
                    #endif
            }
    }
}

private struct DewPointCurrentWeatherView: View {
    let reading: DewPointReading
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(DewPointComfortScale.color(for: reading.dewPointCelsius))
                Spacer(minLength: 12)
                Image(systemName: reading.symbolName)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.cyan)
                    .padding(.top, 6)
            }
            HStack {
                Label(DewPointFormatters.temperature(reading.temperature), systemImage: "thermometer.medium")
                Label(DewPointFormatters.percent(reading.humidity), systemImage: "humidity")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            DewPointDayTimelineView(reading: reading)

            HStack {
                Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 12)
            }
            DewPointWeatherErrorView(message: errorMessage)
        }
    }
}

private struct DewPointForecastSection: View {
    let reading: DewPointReading

    var body: some View {
        if reading.hasFutureForecast {
            VStack(alignment: .leading, spacing: 12) {
                Text("Forecast")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                DewPointWeatherCard {
                    VStack(alignment: .leading, spacing: 16) {
                        DewPointForecastView(reading: reading)
                        Divider()
                        Link("Data from \(DewPointConfiguration.appleWeatherTrademark)",
                             destination: DewPointConfiguration.appleWeatherLegalAttributionURL)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .accessibilityLabel("Weather data from \(DewPointConfiguration.appleWeatherTrademark). Opens legal attribution.")
                    }
                }
            }
        }
    }
}

private struct DewPointWeatherErrorView: View {
    let message: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
private extension DewPointReading {
    var hasFutureForecast: Bool {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: observedAt)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
        return dailyForecastPoints.contains { $0.date >= tomorrow }
    }
}

#endif
