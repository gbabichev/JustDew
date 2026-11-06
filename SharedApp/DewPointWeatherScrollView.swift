#if os(iOS) || os(macOS)
import SwiftUI
#if os(iOS)
import UIKit
#endif

extension EnvironmentValues {
    @Entry var weatherDashboardViewport: CGSize? = nil
    @Entry var weatherDashboardLayout = WeatherLayoutPolicy()
    @Entry var weatherLocationPickerRequested: Binding<Bool>? = nil
}

struct DewPointWeatherScrollView: View {
    let reading: DewPointReading?
    let isLoading: Bool
    let errorMessage: String?
    let refresh: @MainActor @Sendable () async -> Void
    @Environment(\.weatherDashboardViewport) private var viewport
    @State private var measuredViewport: CGSize?

    var body: some View {
        ScrollView {
            DewPointWeatherContent(reading: reading, isLoading: isLoading, errorMessage: errorMessage)
                .environment(\.weatherDashboardViewport, viewport ?? measuredViewport)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { measuredViewport = $0 }
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.weatherDashboardViewport) private var viewport

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var layout: WeatherLayoutPolicy {
        #if os(iOS)
        let regularWidth = horizontalSizeClass == .regular
        #else
        let regularWidth = false
        #endif
        return WeatherLayoutPolicy(viewport: viewport, regularWidth: regularWidth,
                                   accessibility: dynamicTypeSize.isAccessibilitySize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.outerGap) {
            if let errorMessage {
                WeatherUpdateNotice(message: errorMessage, showsCachedForecast: reading != nil)
            }
            if let reading {
                let forecast = WeatherDashboardForecast(reading: reading)
                if !layout.accessibility {
                    AdaptiveWeatherDashboard(reading: reading, forecast: forecast)
                } else {
                    VStack(spacing: layout.accessibilityCardGap) {
                        DewPointNowCard(reading: reading)
                        WeatherForecastCard(reading: reading, forecast: forecast, metric: .dewPoint)
                        WeatherNowCard(reading: reading, today: forecast.days.first?.weather)
                        WeatherForecastCard(reading: reading, forecast: forecast, metric: .temperature)
                    }
                }
                WeatherDashboardFooter(reading: reading, isLoading: isLoading)
            } else {
                VStack(spacing: 12) {
                    if isLoading {
                        ProgressView("Loading weather…")
                    } else {
                        ContentUnavailableView("No Weather", systemImage: "cloud.sun")
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .environment(\.weatherDashboardLayout, layout)
        .frame(maxWidth: WeatherLayoutPolicy.maximumContentWidth, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(layout.contentPadding)
        .padding(.bottom, layout.bottomPadding)
    }
}

private struct LandscapeCurrentCard: View {
    let reading: DewPointReading
    let today: WeatherForecastDay?
    let metric: WeatherForecastMetric
    @ScaledMetric(relativeTo: .largeTitle) private var readingSize: CGFloat = WeatherLayoutPolicy.Platform.current.readingSize

    var body: some View {
        WeatherDashboardCard(title: metric == .dewPoint ? "Dew Point Now" : "Weather Now",
                             symbol: metric == .dewPoint ? "drop.degreesign" : "thermometer.medium",
                             fillsHeight: true, showsDewPointInfo: metric == .dewPoint, showsWeatherDetails: metric == .temperature) {
            HStack(alignment: .center, spacing: 12) {
                if metric == .dewPoint {
                    DewPointExplanationButton {
                        Text(DewPointFormatters.temperature(reading.dewPoint))
                            .font(.system(size: readingSize, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(DewPointComfortScale.color(for: reading.dewPointCelsius))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .accessibilityLabel("Dew point \(DewPointFormatters.temperature(reading.dewPoint))")
                } else {
                    Text(DewPointFormatters.temperature(reading.temperature))
                        .foregroundStyle(WeatherTemperatureColors.color(forCelsius: reading.temperatureCelsius))
                        .font(.system(size: readingSize, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                if metric == .dewPoint {
                    Label("Humidity \(DewPointFormatters.percent(reading.humidity))", systemImage: "humidity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Label(reading.localizedCondition, systemImage: reading.symbolName)
                            .modifier(WeatherConditionSymbolStyle(symbolName: reading.symbolName))
                        if let apparent = reading.apparentTemperatureCelsius {
                            Text("Feels like \(temperature(apparent))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }
            }
            if metric == .temperature, let today {
                HStack(spacing: 10) {
                    Label(temperature(today.highTemperatureCelsius), systemImage: "arrow.up")
                    Label(temperature(today.lowTemperatureCelsius), systemImage: "arrow.down")
                    Spacer(minLength: 0)
                    Label("\(DewPointFormatters.percent(today.precipitationChance)) chance today", systemImage: "cloud.rain")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if metric == .dewPoint {
                DewPointComfortSummary(reading: reading, compact: true)
            }
            Spacer(minLength: 0)
            DewPointCurrentDayTimelineView(reading: reading,
                                   metric: metric == .dewPoint ? .dewPoint : .temperature)
        }
        .modifier(WeatherDetailsPresentation(reading: metric == .temperature ? reading : nil))
    }

    private func temperature(_ value: Double) -> String {
        DewPointFormatters.temperature(Measurement(value: value, unit: .celsius))
    }
}

private struct AdaptiveWeatherDashboard: View {
    let reading: DewPointReading
    let forecast: WeatherDashboardForecast
    @Environment(\.weatherDashboardLayout) private var layout

    var body: some View {
        VStack(spacing: layout.dashboardGap) {
            DashboardCurrentCards(reading: reading, today: forecast.days.first?.weather)
            DashboardForecastCards(reading: reading, forecast: forecast)
        }
    }
}

private struct DashboardCurrentCards: View {
    let reading: DewPointReading
    let today: WeatherForecastDay?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: WeatherLayoutPolicy.columnGap) {
                ForEach([WeatherForecastMetric.dewPoint, .temperature], id: \.self) { metric in
                    CurrentConditionsStrip(reading: reading, today: today, metric: metric, fillsHeight: true)
                        .frame(minWidth: WeatherLayoutPolicy.minimumColumnWidth, maxWidth: .infinity)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: WeatherLayoutPolicy.stackedCardGap) {
                ForEach([WeatherForecastMetric.dewPoint, .temperature], id: \.self) { metric in
                    CurrentConditionsStrip(reading: reading, today: today, metric: metric)
                }
            }
        }
    }
}

private struct DashboardForecastCards: View {
    let reading: DewPointReading
    let forecast: WeatherDashboardForecast
    @Environment(\.weatherDashboardLayout) private var layout

    var body: some View {
        if layout.forecastArrangement == .adaptiveColumns {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: WeatherLayoutPolicy.columnGap) {
                    ForEach([WeatherForecastMetric.dewPoint, .temperature], id: \.self) { metric in
                        WeatherForecastCard(reading: reading, forecast: forecast, metric: metric)
                            .frame(minWidth: WeatherLayoutPolicy.minimumColumnWidth, maxWidth: .infinity)
                    }
                }
                stackedCards
            }
        } else {
            stackedCards
        }
    }

    private var stackedCards: some View {
        VStack(spacing: WeatherLayoutPolicy.stackedCardGap) {
            ForEach([WeatherForecastMetric.dewPoint, .temperature], id: \.self) { metric in
                WeatherForecastCard(reading: reading, forecast: forecast, metric: metric)
            }
        }
    }
}

private struct CurrentConditionsStrip: View {
    let reading: DewPointReading
    let today: WeatherForecastDay?
    let metric: WeatherForecastMetric
    var fillsHeight = false

    var body: some View {
        WeatherDashboardCard(title: metric == .dewPoint ? "Dew Point" : "Weather",
                             symbol: metric == .dewPoint ? "drop.degreesign" : "thermometer.medium",
                             fillsHeight: fillsHeight, spacing: .compact, showsDewPointInfo: metric == .dewPoint,
                             showsWeatherDetails: metric == .temperature) {
            HStack(alignment: .center, spacing: 16) {
                if metric == .dewPoint {
                    DewPointExplanationButton {
                        Text(DewPointFormatters.temperature(reading.dewPoint))
                            .foregroundStyle(DewPointComfortScale.color(for: reading.dewPointCelsius))
                    }
                    .accessibilityLabel("Dew point \(DewPointFormatters.temperature(reading.dewPoint))")
                } else {
                    Text(DewPointFormatters.temperature(reading.temperature))
                        .foregroundStyle(WeatherTemperatureColors.color(forCelsius: reading.temperatureCelsius))
                }
                VStack(alignment: .leading, spacing: 3) {
                    if metric == .dewPoint {
                        Label("Humidity \(DewPointFormatters.percent(reading.humidity))", systemImage: "humidity")
                            .foregroundStyle(.secondary)
                        DewPointComfortSummary(reading: reading, compact: true)
                    } else {
                        HStack(spacing: 8) {
                            Label(reading.localizedCondition, systemImage: reading.symbolName)
                                .modifier(WeatherConditionSymbolStyle(symbolName: reading.symbolName))
                            if let apparent = reading.apparentTemperatureCelsius {
                                Text("Feels like \(temperature(apparent))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let today {
                            HStack(spacing: 10) {
                                Label(temperature(today.highTemperatureCelsius), systemImage: "arrow.up")
                                Label(temperature(today.lowTemperatureCelsius), systemImage: "arrow.down")
                                Label(DewPointFormatters.percent(today.precipitationChance), systemImage: "cloud.rain")
                                    .accessibilityLabel("Chance of precipitation \(DewPointFormatters.percent(today.precipitationChance))")
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(.largeTitle, design: .rounded).weight(.semibold))
            .monospacedDigit()
            if fillsHeight { Spacer(minLength: 0) }
            DewPointCurrentDayTimelineView(reading: reading, trackHeight: 5, markerSize: 10,
                                   metric: metric == .dewPoint ? .dewPoint : .temperature)
        }
        .modifier(WeatherDetailsPresentation(reading: metric == .temperature ? reading : nil))
    }

    private func temperature(_ value: Double) -> String {
        DewPointFormatters.temperature(Measurement(value: value, unit: .celsius))
    }
}

#if os(iOS)
@available(iOS 27.1, *)
struct DewPointFoldedWeatherDashboard: View {
    let reading: DewPointReading?
    let isLoading: Bool
    let errorMessage: String?
    let axis: Axis
    let locations: [DewPointLocation]
    @Binding var selectedID: String?
    let refresh: @MainActor @Sendable () async -> Void

    // Align the current cards initially without linking either pane's scrolling.
    @State private var currentCardHeights: [WeatherForecastMetric: CGFloat] = [:]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var layout: WeatherLayoutPolicy {
        WeatherLayoutPolicy(accessibility: dynamicTypeSize.isAccessibilitySize,
                            presentation: axis == .horizontal ? .foldedBook : .foldedTabletop)
    }

    var body: some View {
        // The system split arrangement places each pane in the usable region on
        // its side of the fold, including asymmetric toolbar and sidebar insets.
        ArrangementView {
            FoldedWeatherPane(reading: reading, metric: .dewPoint,
                              scrollOverflowEdges: axis == .horizontal ? .vertical : .top, currentCardHeights: $currentCardHeights,
                              isLoading: isLoading, errorMessage: errorMessage, refresh: { await refresh() })
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    DewPointPageControl(locationIDs: locations.map(\.id), selectedID: $selectedID)
                        .padding(.vertical, 6)
                }
                .splitArrangementLayoutRatio(0.5)
        } secondary: {
            FoldedWeatherPane(reading: reading, metric: .temperature,
                              scrollOverflowEdges: axis == .horizontal ? .vertical : .bottom, currentCardHeights: $currentCardHeights,
                              isLoading: isLoading, errorMessage: errorMessage, refresh: { await refresh() })
        }
        .environment(\.weatherDashboardLayout, layout)
        .arrangementViewStyle(.split.axes(axis == .horizontal ? .horizontal : .vertical))
        .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { value in
            guard abs(value.translation.width) > 60,
                  abs(value.translation.width) > abs(value.translation.height) * 1.5,
                  let index = locations.firstIndex(where: { $0.id == selectedID }) else { return }
            let next = index + (value.translation.width < 0 ? 1 : -1)
            if locations.indices.contains(next) { selectedID = locations[next].id }
        })
    }
}

private struct FoldedWeatherPane: View {
    let reading: DewPointReading?
    let metric: WeatherForecastMetric
    let scrollOverflowEdges: Edge.Set
    @Binding var currentCardHeights: [WeatherForecastMetric: CGFloat]
    let isLoading: Bool
    let errorMessage: String?
    let refresh: @MainActor @Sendable () async -> Void

    @State private var position = ScrollPosition(edge: .top)
    @Environment(\.weatherDashboardLayout) private var layout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: layout.foldedContentGap) {
                if let errorMessage {
                    WeatherUpdateNotice(message: errorMessage, showsCachedForecast: reading != nil)
                }
                if let reading {
                    let forecast = WeatherDashboardForecast(reading: reading)
                    FoldedMetricCards(reading: reading, forecast: forecast, metric: metric,
                                      currentCardHeights: $currentCardHeights)
                    WeatherDashboardFooter(reading: reading, isLoading: isLoading)
                } else if isLoading {
                    ProgressView("Loading weather…")
                } else {
                    ContentUnavailableView("No Weather", systemImage: "cloud.sun")
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(layout.foldedContentPadding)
            .fixedSize(horizontal: false, vertical: true)
        }
        .scrollPosition($position)
        .onChange(of: reading?.location.id) { _, _ in
            position.scrollTo(edge: .top)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable { await refresh() }
        .scrollClipDisabled()
        .mask {
            // Allow scrolling beneath the outer screen edges, but never across the fold.
            Rectangle()
                .ignoresSafeArea(.container, edges: scrollOverflowEdges)
        }
    }
}

private struct FoldedMetricCards: View {
    let reading: DewPointReading
    let forecast: WeatherDashboardForecast
    let metric: WeatherForecastMetric
    @Binding var currentCardHeights: [WeatherForecastMetric: CGFloat]
    @Environment(\.weatherDashboardLayout) private var layout

    var body: some View {
        switch layout.foldedArrangement {
        case .columns:
            HStack(alignment: .top, spacing: layout.foldedCardGap) {
                FoldedCurrentMetricCard(reading: reading, today: forecast.days.first?.weather,
                                        metric: metric, spacing: .compact)
                    .frame(maxWidth: .infinity)
                WeatherForecastCard(reading: reading, forecast: forecast, metric: metric)
                    .frame(maxWidth: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .matchedStack:
            VStack(spacing: layout.foldedCardGap) {
                FoldedAlignedCurrentCard(reading: reading, today: forecast.days.first?.weather,
                                         metric: metric, heights: $currentCardHeights)
                WeatherForecastCard(reading: reading, forecast: forecast, metric: metric)
            }
        case .accessibleStack:
            VStack(spacing: layout.foldedCardGap) {
                FoldedCurrentMetricCard(reading: reading, today: forecast.days.first?.weather, metric: metric)
                WeatherForecastCard(reading: reading, forecast: forecast, metric: metric)
            }
        }
    }
}

private struct FoldedAlignedCurrentCard: View {
    let reading: DewPointReading
    let today: WeatherForecastDay?
    let metric: WeatherForecastMetric
    @Binding var heights: [WeatherForecastMetric: CGFloat]

    var body: some View {
        LandscapeCurrentCard(reading: reading, today: today, metric: metric)
            .frame(height: heights.values.max())
            .background {
                // Measure the natural size independently of the shared height so
                // both cards can shrink again after a resize or a text-size change.
                LandscapeCurrentCard(reading: reading, today: today, metric: metric)
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .accessibilityHidden(true)
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height in
                        heights[metric] = height
                    }
            }
    }
}

private struct FoldedCurrentMetricCard: View {
    let reading: DewPointReading
    let today: WeatherForecastDay?
    let metric: WeatherForecastMetric
    var spacing: WeatherLayoutPolicy.CardSpacing? = nil

    var body: some View {
        if metric == .dewPoint {
            DewPointNowCard(reading: reading, spacing: spacing)
        } else {
            WeatherNowCard(reading: reading, today: today, spacing: spacing)
        }
    }
}

#if DEBUG && os(iOS)
#Preview("iPhone landscape · side-by-side forecasts", traits: .sizeThatFitsLayout) {
    DewPointWeatherScrollView(reading: DewPointWidgetLoader.sampleReading,
                             isLoading: false, errorMessage: nil, refresh: {})
        .environment(\.horizontalSizeClass, .compact)
        .environment(\.weatherDashboardViewport, CGSize(width: 740, height: 330))
        .frame(width: 740, height: 330)
}
#endif
#endif

private struct WeatherDashboardCard<Content: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    var fillsHeight = false
    var spacing: WeatherLayoutPolicy.CardSpacing? = nil
    var showsDewPointInfo = false
    var showsWeatherDetails = false
    @ViewBuilder var content: Content
    @Environment(\.weatherDashboardLayout) private var layout

    private var resolvedSpacing: WeatherLayoutPolicy.CardSpacing { spacing ?? layout.defaultCardSpacing }

    var body: some View {
        VStack(alignment: .leading, spacing: resolvedSpacing.gap) {
            HStack(spacing: 4) {
                Label {
                    Text(title)
                        .font(.headline.weight(.bold))
                } icon: {
                    Image(systemName: symbol)
                        .foregroundStyle(.tint)
                }
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
                if showsDewPointInfo {
                    DewPointExplanationButton {
                        Image(systemName: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 28, minHeight: 28)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("About dew point and comfort colors")
                }
                if showsWeatherDetails {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .padding(resolvedSpacing.padding)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                #if os(iOS)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                #else
                .fill(Color.primary.opacity(0.04))
                #endif
        }
    }
}

private struct WeatherNowCard: View {
    let reading: DewPointReading
    let today: WeatherForecastDay?
    var fillsHeight = false
    var spacing: WeatherLayoutPolicy.CardSpacing? = nil
    @Environment(\.weatherDashboardLayout) private var layout
    @ScaledMetric(relativeTo: .largeTitle) private var readingSize: CGFloat = WeatherLayoutPolicy.Platform.current.readingSize

    var body: some View {
        WeatherDashboardCard(title: "Weather Now", symbol: "thermometer.medium", fillsHeight: fillsHeight, spacing: spacing, showsWeatherDetails: true) {
            HStack(alignment: .top) {
                Text(DewPointFormatters.temperature(reading.temperature))
                    .foregroundStyle(WeatherTemperatureColors.color(forCelsius: reading.temperatureCelsius))
                    .font(.system(size: readingSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .accessibilityLabel("Temperature \(DewPointFormatters.temperature(reading.temperature))")
                Spacer(minLength: 8)
                Image(systemName: reading.symbolName)
                    .font(.title2)
                    .modifier(WeatherConditionSymbolStyle(symbolName: reading.symbolName))
                    .accessibilityHidden(true)
            }
            Text(reading.localizedCondition)
                .font(.subheadline.weight(.medium))
            if let apparent = reading.apparentTemperatureCelsius {
                Text("Feels like \(DewPointFormatters.temperature(Measurement(value: apparent, unit: .celsius)))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let today {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        Label("High \(temperature(today.highTemperatureCelsius))", systemImage: "arrow.up")
                        Label("Low \(temperature(today.lowTemperatureCelsius))", systemImage: "arrow.down")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label("High \(temperature(today.highTemperatureCelsius))", systemImage: "arrow.up")
                        Label("Low \(temperature(today.lowTemperatureCelsius))", systemImage: "arrow.down")
                    }
                }
                .font(.subheadline)
                Label("\(DewPointFormatters.percent(today.precipitationChance)) chance today", systemImage: "cloud.rain")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if fillsHeight { Spacer(minLength: 0) }
            DewPointCurrentDayTimelineView(reading: reading, metric: .temperature)
                .accessibilityHint("Color shows temperature through the day.")
        }
        .modifier(WeatherDetailsPresentation(reading: reading))
    }

    private func temperature(_ value: Double) -> String {
        DewPointFormatters.temperature(Measurement(value: value, unit: .celsius))
    }
}

private struct DewPointNowCard: View {
    let reading: DewPointReading
    var fillsHeight = false
    var spacing: WeatherLayoutPolicy.CardSpacing? = nil
    @Environment(\.weatherDashboardLayout) private var layout
    @ScaledMetric(relativeTo: .largeTitle) private var readingSize: CGFloat = WeatherLayoutPolicy.Platform.current.readingSize

    var body: some View {
        WeatherDashboardCard(title: "Dew Point Now", symbol: "drop.degreesign", fillsHeight: fillsHeight, spacing: spacing, showsDewPointInfo: true) {
            DewPointExplanationButton {
                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.system(size: readingSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundStyle(DewPointComfortScale.color(for: reading.dewPointCelsius))
            }
            .accessibilityLabel("Dew point \(DewPointFormatters.temperature(reading.dewPoint))")
            Label("Humidity \(DewPointFormatters.percent(reading.humidity))", systemImage: "humidity")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            DewPointComfortSummary(reading: reading, compact: layout.usesCompactComfort(spacing: spacing))
            if fillsHeight { Spacer(minLength: 0) }
            DewPointCurrentDayTimelineView(reading: reading)
                .accessibilityHint("Color shows dew point comfort through the day.")
        }
    }
}

private enum WeatherForecastMetric: Hashable {
    case temperature, dewPoint

    var title: LocalizedStringKey {
        switch self {
        case .temperature: "10-Day Weather"
        case .dewPoint: "10-Day Dew Point"
        }
    }

    var symbol: String { self == .temperature ? "calendar" : "drop.degreesign" }

    func low(_ day: WeatherDashboardDay) -> Double? {
        self == .temperature ? day.weather?.lowTemperatureCelsius : day.lowDewPointCelsius
    }

    func high(_ day: WeatherDashboardDay) -> Double? {
        self == .temperature ? day.weather?.highTemperatureCelsius : day.highDewPointCelsius
    }

    func color(_ value: Double) -> Color {
        if self == .dewPoint { return DewPointComfortScale.color(for: value) }
        return WeatherTemperatureColors.color(forCelsius: value)
    }
}

private struct WeatherForecastCard: View {
    let reading: DewPointReading
    let forecast: WeatherDashboardForecast
    let metric: WeatherForecastMetric
    @Environment(\.weatherDashboardLayout) private var layout

    var body: some View {
        let days = metric == .temperature ? forecast.weatherDays : forecast.dewPointDays
        let metrics = layout.forecastStyle.metrics
        WeatherDashboardCard(title: metric.title, symbol: metric.symbol, spacing: metrics.cardSpacing) {
            if !days.isEmpty {
                if metrics.rowStyle == .accessible {
                    VStack(spacing: metrics.rowGap) {
                        forecastRows(days, metrics: metrics)
                    }
                } else {
                    Grid(alignment: .leading, horizontalSpacing: 6, verticalSpacing: metrics.rowGap) {
                        forecastRows(days, metrics: metrics)
                    }
                }
                if metric == .dewPoint && days.contains(where: \.hasPartialDewPoint) {
                    Text("* Range covers available hours only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if metrics.showsExplanation {
                    Text("Bars compare daily lows and highs across the available forecast.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView("Forecast Unavailable", systemImage: metric.symbol,
                                       description: Text("Refresh to load the latest forecast."))
            }
        }
    }

    private func forecastRows(_ days: [WeatherDashboardDay], metrics: WeatherLayoutPolicy.ForecastMetrics) -> some View {
        ForEach(days) { day in
            WeatherForecastRow(
                day: day, reading: reading, metric: metric,
                scale: metric == .temperature ? forecast.temperatureScale : forecast.dewPointScale,
                style: metrics.rowStyle, minimumHeight: metrics.rowHeight
            )
        }
    }
}

private struct WeatherForecastRow: View {
    let day: WeatherDashboardDay
    let reading: DewPointReading
    let metric: WeatherForecastMetric
    let scale: WeatherRangeScale
    let style: WeatherLayoutPolicy.ForecastRowStyle
    let minimumHeight: CGFloat

    private var dayLabel: String {
        let label = DewPointFormatters.forecastDayLabel(day.date, relativeTo: Date(),
                                                       calendar: reading.forecastCalendar)
        return metric == .dewPoint && day.hasPartialDewPoint ? label + "*" : label
    }

    var body: some View {
        Group {
            if style == .accessible {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(dayLabel).font(.body.weight(.medium))
                        Spacer(minLength: 8)
                        if metric == .temperature, let weather = day.weather {
                            WeatherForecastCondition(weather: weather)
                        }
                    }
                    WeatherForecastValues(day: day, metric: metric, scale: scale,
                                          current: currentValue, style: .accessible)
                }
                .frame(minHeight: minimumHeight)
            } else {
                GridRow(alignment: .center) {
                    Text(dayLabel)
                        .font(style == .roomy ? .subheadline.weight(.medium) : .caption.weight(.medium))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .gridColumnAlignment(.leading)
                        .frame(minHeight: minimumHeight, alignment: .leading)
                    if metric == .temperature, let weather = day.weather {
                        WeatherForecastCondition(weather: weather, style: style)
                            .frame(width: style.conditionWidth)
                    }
                    WeatherForecastValues(day: day, metric: metric, scale: scale,
                                          current: currentValue, style: style)
                        .frame(minHeight: minimumHeight)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayLabel)
        .accessibilityValue(accessibilitySummary)
    }

    private var currentValue: Double? {
        guard reading.forecastCalendar.isDate(day.date, inSameDayAs: reading.observedAt) else { return nil }
        return metric == .temperature ? reading.temperatureCelsius : reading.dewPointCelsius
    }

    private var accessibilitySummary: Text {
        guard let low = metric.low(day), let high = metric.high(day) else { return Text("Forecast unavailable") }
        let lowText = DewPointFormatters.temperature(Measurement(value: low, unit: .celsius))
        let highText = DewPointFormatters.temperature(Measurement(value: high, unit: .celsius))
        if metric == .temperature, let weather = day.weather {
            return Text("\(weather.localizedCondition). Low \(lowText), high \(highText). \(DewPointFormatters.percent(weather.precipitationChance)) chance of precipitation.")
        }
        if day.hasPartialDewPoint {
            return Text("Dew point low \(lowText), high \(highText). Available hours only.")
        }
        return Text("Dew point low \(lowText), high \(highText).")
    }
}

private struct WeatherForecastCondition: View {
    let weather: WeatherForecastDay
    var style: WeatherLayoutPolicy.ForecastRowStyle = .accessible

    var body: some View {
        let layout = style != .accessible ? AnyLayout(HStackLayout(spacing: 3)) : AnyLayout(VStackLayout(spacing: 2))
        layout {
            Image(systemName: weather.symbolName)
                .font(style == .roomy ? .subheadline : .caption)
                .modifier(WeatherConditionSymbolStyle(symbolName: weather.symbolName))
                .frame(width: style == .accessible ? nil : style.symbolWidth)
            if style != .accessible || weather.precipitationChance > 0 {
                Text(weather.precipitationChance > 0 ? DewPointFormatters.percent(weather.precipitationChance) : "")
                    .font(style == .roomy ? .caption : .caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(width: style == .accessible ? nil : style.precipitationWidth, alignment: .leading)
            }
        }
    }
}

private struct WeatherForecastValues: View {
    let day: WeatherDashboardDay
    let metric: WeatherForecastMetric
    let scale: WeatherRangeScale
    let current: Double?
    let style: WeatherLayoutPolicy.ForecastRowStyle

    var body: some View {
        HStack(spacing: 6) {
            if let low = metric.low(day), let high = metric.high(day), low.isFinite, high.isFinite {
                Text(degrees(low))
                    .font(style == .roomy ? .subheadline : .caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: style == .accessible ? nil : style.valueWidth, alignment: .trailing)
                    .layoutPriority(1)
                WeatherRangeBar(low: low, high: high, scale: scale,
                                colors: [metric.color(low), metric.color(high)], current: current)
                    .frame(minWidth: 24)
                Text(degrees(high))
                    .font(style == .roomy ? .subheadline.weight(.medium) : .caption.weight(.medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: style == .accessible ? nil : style.valueWidth, alignment: .trailing)
                    .layoutPriority(1)
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func degrees(_ value: Double) -> String {
        "\(DewPointFormatters.temperatureValue(Measurement(value: value, unit: .celsius)))°"
    }
}

private struct WeatherRangeBar: View {
    let low: Double
    let high: Double
    let scale: WeatherRangeScale
    let colors: [Color]
    let current: Double?

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let start = scale.fraction(for: low) * width
            let end = scale.fraction(for: high) * width
            let rangeWidth = min(width, max(end - start, 4))
            let x = min(start, width - rangeWidth)
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: rangeWidth)
                    .offset(x: x)
                if let current, current >= low, current <= high {
                    Circle()
                        .fill(.primary)
                        .overlay { Circle().stroke(.background, lineWidth: 1.5) }
                        .frame(width: 8, height: 8)
                        .offset(x: min(max(scale.fraction(for: current) * width - 4, 0), max(width - 8, 0)))
                }
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

private struct WeatherDashboardFooter: View {
    let reading: DewPointReading
    let isLoading: Bool
    @Environment(\.weatherDashboardLayout) private var layout

    #if os(iOS)
    @State private var showsAbout = false
    #endif

    var body: some View {
        let footerLayout = layout.footerInline ? AnyLayout(HStackLayout(spacing: 12))
            : AnyLayout(VStackLayout(alignment: .center, spacing: 8))
        footerLayout {
            HStack(spacing: 8) {
                if isLoading { ProgressView().controlSize(.small) }
                Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt, timeZone: reading.forecastCalendar.timeZone, includesDate: !reading.forecastCalendar.isDate(reading.fetchedAt, inSameDayAs: Date())))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Link("Data from \(DewPointConfiguration.appleWeatherTrademark)", destination: DewPointConfiguration.appleWeatherLegalAttributionURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Weather data from \(DewPointConfiguration.appleWeatherTrademark). Opens legal attribution.")
                #if os(iOS)
                Button("About JustDew", systemImage: "questionmark.circle") {
                    showsAbout = true
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
                #endif
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        #if os(iOS)
        .sheet(isPresented: $showsAbout) {
            AboutView()
                .presentationSizing(.form)
        }
        #endif
    }
}

struct WeatherUpdateNotice: View {
    let message: String
    let showsCachedForecast: Bool
    var isSetup = false
    @Environment(\.openURL) private var openURL
    @Environment(\.refresh) private var refresh
    @Environment(\.weatherLocationPickerRequested) private var locationPickerRequested
    @State private var isRetrying = false

    private var permissionDenied: Bool {
        message == DewPointError.permissionDenied.localizedDescription
    }

    private var locationUnavailable: Bool {
        message == DewPointError.locationUnavailable.localizedDescription
    }

    private var usingLastKnownLocation: Bool {
        message == DewPointError.usingLastKnownLocation.localizedDescription
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: permissionDenied || locationUnavailable || usingLastKnownLocation ? "location.slash" : "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.subheadline)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if showsCachedForecast && !usingLastKnownLocation {
                    Text("Showing your last saved forecast.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if permissionDenied {
                    #if os(iOS)
                    Text(isSetup
                         ? LocalizedStringResource("Allow location access in Settings, or use Search for a City below.")
                         : LocalizedStringResource("Allow location access in Settings, or search for a city in Locations."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    #else
                    Text("Allow JustDew to use your location in System Settings → Privacy & Security → Location Services, or search for a city in Locations.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    #endif
                } else if locationUnavailable || usingLastKnownLocation {
                    Text(usingLastKnownLocation
                         ? LocalizedStringResource("Location lookup failed. Weather was updated for your last known location.")
                         : (isSetup
                            ? LocalizedStringResource("Try Use Current Location again, or use Search for a City below.")
                            : LocalizedStringResource("Try refreshing again, or search for a city in Locations.")))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !isSetup {
                        ViewThatFits(in: .horizontal) {
                            HStack { recoveryButtons }
                            VStack(alignment: .leading) { recoveryButtons }
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .disabled(isRetrying)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .multilineTextAlignment(.leading)
    }

    private var title: String {
        if permissionDenied { return String(localized: "Location access is off") }
        if locationUnavailable { return String(localized: "Unable to update your location") }
        return message
    }

    @ViewBuilder
    private var recoveryButtons: some View {
        if let refresh {
            Button("Retry") {
                Task {
                    isRetrying = true
                    await refresh()
                    isRetrying = false
                }
            }
        }
        if let locationPickerRequested {
            Button("Choose a City") { locationPickerRequested.wrappedValue = true }
        }
    }
}

#endif
