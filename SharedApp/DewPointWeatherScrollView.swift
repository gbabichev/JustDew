#if os(iOS) || os(macOS)
import SwiftUI

private enum WeatherDashboardPlatformStyle {
    #if os(macOS)
    static let compact = true
    static let readingSize: CGFloat = 32
    #else
    static let compact = false
    static let readingSize: CGFloat = 36
    #endif
}

extension EnvironmentValues {
    @Entry var weatherDashboardViewport: CGSize? = nil
}

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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.weatherDashboardViewport) private var viewport

    private var compactSingleColumn: Bool {
        !dynamicTypeSize.isAccessibilitySize
    }

    private var heightConstrained: Bool {
        guard let viewport else { return false }
        return viewport.width >= 700 && viewport.width > viewport.height
            && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WeatherDashboardPlatformStyle.compact ? 12 : (heightConstrained ? 14 : 16)) {
            if let reading {
                let forecast = WeatherDashboardForecast(reading: reading)
                ViewThatFits(in: .horizontal) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        WeatherDashboardColumns(reading: reading, forecast: forecast, heightConstrained: heightConstrained)
                    }
                    if !dynamicTypeSize.isAccessibilitySize {
                        WeatherDashboardColumns(reading: reading, forecast: forecast, compact: true, heightConstrained: heightConstrained)
                    }
                    VStack(spacing: compactSingleColumn ? 12 : 16) {
                        DewPointNowCard(reading: reading, compact: compactSingleColumn)
                        WeatherForecastCard(reading: reading, forecast: forecast, metric: .dewPoint,
                                            compact: compactSingleColumn, roomy: compactSingleColumn)
                        WeatherNowCard(reading: reading, today: forecast.days.first?.weather,
                                       compact: compactSingleColumn)
                        WeatherForecastCard(reading: reading, forecast: forecast, metric: .temperature,
                                            compact: compactSingleColumn, roomy: compactSingleColumn)
                    }
                }
                WeatherDashboardFooter(reading: reading, isLoading: isLoading, errorMessage: errorMessage, compact: heightConstrained || WeatherDashboardPlatformStyle.compact)
            } else {
                VStack(spacing: 12) {
                    if isLoading {
                        ProgressView("Loading weather…")
                    } else {
                        ContentUnavailableView("No Weather", systemImage: "cloud.sun")
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: 1_100, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(heightConstrained || WeatherDashboardPlatformStyle.compact ? 12 : 14)
        .padding(.bottom, heightConstrained ? 4 : (WeatherDashboardPlatformStyle.compact ? 12 : 16))
    }
}

private struct LandscapeCurrentCard: View {
    let reading: DewPointReading
    let today: WeatherForecastDay?
    let metric: WeatherForecastMetric
    @ScaledMetric(relativeTo: .largeTitle) private var readingSize: CGFloat = WeatherDashboardPlatformStyle.readingSize

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
                        Label(reading.condition, systemImage: reading.symbolName)
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
            DewPointDayTimelineView(reading: reading, referenceDate: Date(),
                                   metric: metric == .dewPoint ? .dewPoint : .temperature)
            if metric == .dewPoint {
                DewPointComfortHours(reading: reading, compact: true)
            }
        }
        .modifier(WeatherDetailsPresentation(reading: metric == .temperature ? reading : nil))
    }

    private func temperature(_ value: Double) -> String {
        DewPointFormatters.temperature(Measurement(value: value, unit: .celsius))
    }
}

private struct WeatherDashboardColumns: View {
    let reading: DewPointReading
    let forecast: WeatherDashboardForecast
    var compact = false
    var heightConstrained = false

    var body: some View {
        // Both rows share one fit decision, including the narrower portrait layout.
        VStack(spacing: WeatherDashboardPlatformStyle.compact ? 12 : (heightConstrained ? 14 : 16)) {
            HStack(alignment: .top, spacing: WeatherDashboardPlatformStyle.compact ? 12 : 16) {
                if heightConstrained {
                    LandscapeCurrentCard(reading: reading, today: forecast.days.first?.weather, metric: .dewPoint)
                        .frame(maxWidth: .infinity)
                    LandscapeCurrentCard(reading: reading, today: forecast.days.first?.weather, metric: .temperature)
                        .frame(maxWidth: .infinity)
                } else {
                    DewPointNowCard(reading: reading, fillsHeight: true)
                        .frame(minWidth: compact ? 260 : 320, maxWidth: .infinity)
                    WeatherNowCard(reading: reading, today: forecast.days.first?.weather,
                                   fillsHeight: true)
                        .frame(minWidth: compact ? 260 : 320, maxWidth: .infinity)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: WeatherDashboardPlatformStyle.compact ? 12 : 16) {
                WeatherForecastCard(reading: reading, forecast: forecast, metric: .dewPoint, compact: compact || heightConstrained, roomy: !heightConstrained, dense: heightConstrained)
                    .frame(minWidth: compact ? 260 : 320, maxWidth: .infinity)
                WeatherForecastCard(reading: reading, forecast: forecast, metric: .temperature, compact: compact || heightConstrained, roomy: !heightConstrained, dense: heightConstrained)
                    .frame(minWidth: compact ? 260 : 320, maxWidth: .infinity)
            }
        }
        .frame(minWidth: compact ? 560 : 720)
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

    // Shared with the folded panes through $linkedScroll bindings.
    // periphery:ignore
    @State private var linkedScroll = FoldedLinkedScroll()

    var body: some View {
        // The system split arrangement places each pane in the usable region on
        // its side of the fold, including asymmetric toolbar and sidebar insets.
        ArrangementView {
            FoldedWeatherPane(reading: reading, metric: .dewPoint, showsCardsSideBySide: axis == .vertical,
                              scrollOverflowEdges: axis == .horizontal ? .vertical : .top, linkedScroll: $linkedScroll,
                              isLoading: isLoading, errorMessage: errorMessage, refresh: { await refresh() })
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    DewPointPageControl(locationIDs: locations.map(\.id), selectedID: $selectedID)
                        .padding(.vertical, 6)
                }
                .splitArrangementLayoutRatio(0.5)
        } secondary: {
            FoldedWeatherPane(reading: reading, metric: .temperature, showsCardsSideBySide: axis == .vertical,
                              scrollOverflowEdges: axis == .horizontal ? .vertical : .bottom, linkedScroll: $linkedScroll,
                              isLoading: isLoading, errorMessage: errorMessage, refresh: { await refresh() })
        }
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
    let showsCardsSideBySide: Bool
    let scrollOverflowEdges: Edge.Set
    @Binding var linkedScroll: FoldedLinkedScroll
    let isLoading: Bool
    let errorMessage: String?
    let refresh: @MainActor @Sendable () async -> Void

    @State private var position = ScrollPosition(edge: .top)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let reading {
                    let forecast = WeatherDashboardForecast(reading: reading)
                    FoldedMetricCards(reading: reading, forecast: forecast, metric: metric,
                                      showsCardsSideBySide: showsCardsSideBySide, linkedScroll: $linkedScroll)
                    WeatherDashboardFooter(reading: reading, isLoading: isLoading, errorMessage: errorMessage)
                } else if isLoading {
                    ProgressView("Loading weather…")
                } else {
                    ContentUnavailableView("No Weather", systemImage: "cloud.sun")
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(14)
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height in
                linkedScroll.contentHeights[metric] = height
            }
            .frame(minHeight: linkedScroll.minimumContentHeight(for: metric), alignment: .top)
        }
        .scrollPosition($position)
        .onScrollPhaseChange { _, phase in
            if phase == .tracking || phase == .interacting { linkedScroll.driver = metric }
        }
        .onScrollGeometryChange(for: FoldedScrollGeometry.self, of: { geometry in
            FoldedScrollGeometry(offset: max(0, geometry.contentOffset.y + geometry.contentInsets.top),
                                 visibleHeight: max(0, geometry.containerSize.height
                                     - geometry.contentInsets.top - geometry.contentInsets.bottom))
        }) { _, geometry in
            linkedScroll.visibleHeights[metric] = geometry.visibleHeight
            if linkedScroll.driver == metric, abs(linkedScroll.offset - geometry.offset) > 0.5 {
                linkedScroll.offset = geometry.offset
            }
        }
        .onChange(of: linkedScroll.offset) { _, offset in
            guard linkedScroll.driver != metric else { return }
            if offset == 0 { position.scrollTo(edge: .top) }
            else { position.scrollTo(y: offset) }
        }
        .onChange(of: reading?.location.id) { _, _ in
            position.scrollTo(edge: .top)
            linkedScroll.offset = 0
            linkedScroll.driver = nil
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
    let showsCardsSideBySide: Bool
    @Binding var linkedScroll: FoldedLinkedScroll
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if showsCardsSideBySide && !dynamicTypeSize.isAccessibilitySize {
            HStack(alignment: .top, spacing: 16) {
                FoldedCurrentMetricCard(reading: reading, today: forecast.days.first?.weather,
                                        metric: metric, compact: true)
                    .frame(maxWidth: .infinity)
                WeatherForecastCard(reading: reading, forecast: forecast, metric: metric, compact: true)
                    .frame(maxWidth: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else if !dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 14) {
                FoldedAlignedCurrentCard(reading: reading, today: forecast.days.first?.weather,
                                         metric: metric, heights: $linkedScroll.currentCardHeights)
                WeatherForecastCard(reading: reading, forecast: forecast, metric: metric,
                                    compact: true, dense: true)
            }
        } else {
            VStack(spacing: 16) {
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
    var compact = false

    var body: some View {
        if metric == .dewPoint {
            DewPointNowCard(reading: reading, compact: compact)
        } else {
            WeatherNowCard(reading: reading, today: today, compact: compact)
        }
    }
}

private struct FoldedScrollGeometry: Equatable {
    let offset: CGFloat
    let visibleHeight: CGFloat
}

private struct FoldedLinkedScroll {
    var driver: WeatherForecastMetric?
    var offset: CGFloat = 0
    var contentHeights: [WeatherForecastMetric: CGFloat] = [:]
    var visibleHeights: [WeatherForecastMetric: CGFloat] = [:]
    var currentCardHeights: [WeatherForecastMetric: CGFloat] = [:]

    // Give both panes the same travel distance, even when one has less content
    // or less visible space because of its page controls or the device's pose.
    func minimumContentHeight(for metric: WeatherForecastMetric) -> CGFloat {
        let travel = contentHeights.map { key, height in
            max(0, height - (visibleHeights[key] ?? height))
        }.max() ?? 0
        return travel + (visibleHeights[metric] ?? 0)
    }
}

#endif

private struct WeatherDashboardCard<Content: View>: View {
    let title: LocalizedStringKey
    let symbol: String
    var fillsHeight = false
    var compact = false
    var showsDewPointInfo = false
    var showsWeatherDetails = false
    @ViewBuilder var content: Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var compactSpacing: Bool {
        compact || (WeatherDashboardPlatformStyle.compact && !dynamicTypeSize.isAccessibilitySize)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compactSpacing ? 6 : 10) {
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
        .padding(compactSpacing ? 12 : 14)
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
    var compact = false
    @ScaledMetric(relativeTo: .largeTitle) private var readingSize: CGFloat = WeatherDashboardPlatformStyle.readingSize

    var body: some View {
        WeatherDashboardCard(title: "Weather Now", symbol: "thermometer.medium", fillsHeight: fillsHeight, compact: compact, showsWeatherDetails: true) {
            HStack(alignment: .top) {
                Text(DewPointFormatters.temperature(reading.temperature))
                    .font(.system(size: readingSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .accessibilityLabel("Temperature \(DewPointFormatters.temperature(reading.temperature))")
                Spacer(minLength: 8)
                Image(systemName: reading.symbolName)
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)
                    .accessibilityHidden(true)
            }
            Text(reading.condition)
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
            DewPointDayTimelineView(reading: reading, referenceDate: Date(), metric: .temperature)
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
    var compact = false
    @ScaledMetric(relativeTo: .largeTitle) private var readingSize: CGFloat = WeatherDashboardPlatformStyle.readingSize

    var body: some View {
        WeatherDashboardCard(title: "Dew Point Now", symbol: "drop.degreesign", fillsHeight: fillsHeight, compact: compact, showsDewPointInfo: true) {
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
            DewPointComfortSummary(reading: reading, compact: compact || WeatherDashboardPlatformStyle.compact)
            if fillsHeight { Spacer(minLength: 0) }
            DewPointDayTimelineView(reading: reading, referenceDate: Date())
                .accessibilityHint("Color shows dew point comfort through the day.")
            DewPointComfortHours(reading: reading, compact: compact || WeatherDashboardPlatformStyle.compact)
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
    var compact = false
    var roomy = false
    var dense = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var compactMac: Bool {
        WeatherDashboardPlatformStyle.compact && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        let days = metric == .temperature ? forecast.weatherDays : forecast.dewPointDays
        WeatherDashboardCard(title: metric.title, symbol: metric.symbol, compact: compact && !roomy && !dense) {
            if !days.isEmpty {
                VStack(spacing: compactMac ? 4 : (dense ? 3 : (compact && !roomy ? 3 : 6))) {
                    ForEach(days) { day in
                        WeatherForecastRow(
                            day: day, reading: reading, metric: metric,
                            scale: metric == .temperature ? forecast.temperatureScale : forecast.dewPointScale,
                            compact: compact || compactMac, minimumHeight: compactMac ? 22 : (dense ? 20 : (roomy && compact ? 24 : nil))
                        )
                    }
                }
                if metric == .dewPoint && days.contains(where: \.hasPartialDewPoint) {
                    Text("* Range covers available hours only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !compact && !compactMac {
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
}

private struct WeatherForecastRow: View {
    let day: WeatherDashboardDay
    let reading: DewPointReading
    let metric: WeatherForecastMetric
    let scale: WeatherRangeScale
    var compact = false
    var minimumHeight: CGFloat? = nil

    private var dayLabel: String {
        let label = DewPointFormatters.forecastDayLabel(day.date, relativeTo: Date(),
                                                       calendar: reading.forecastCalendar)
        return metric == .dewPoint && day.hasPartialDewPoint ? label + "*" : label
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if dynamicTypeSize.isAccessibilitySize {
                HStack {
                    Text(dayLabel).font(.body.weight(.medium))
                    Spacer(minLength: 8)
                    if metric == .temperature, let weather = day.weather { WeatherForecastCondition(weather: weather) }
                }
                WeatherForecastValues(day: day, metric: metric, scale: scale,
                                      current: currentValue, usesFixedColumns: false)
            } else {
                HStack(spacing: 6) {
                    Text(dayLabel)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .frame(width: compact ? 42 : 52, alignment: .leading)
                    if metric == .temperature, let weather = day.weather {
                        WeatherForecastCondition(weather: weather, compact: compact)
                            .frame(width: compact ? 54 : 30)
                    }
                    WeatherForecastValues(day: day, metric: metric, scale: scale,
                                          current: currentValue, usesFixedColumns: true)
                }
            }
        }
        .frame(minHeight: minimumHeight ?? (compact && !dynamicTypeSize.isAccessibilitySize ? 18 : 26))
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
            return Text("\(weather.condition). Low \(lowText), high \(highText). \(DewPointFormatters.percent(weather.precipitationChance)) chance of precipitation.")
        }
        if day.hasPartialDewPoint {
            return Text("Dew point low \(lowText), high \(highText). Available hours only.")
        }
        return Text("Dew point low \(lowText), high \(highText).")
    }
}

private struct WeatherForecastCondition: View {
    let weather: WeatherForecastDay
    var compact = false

    var body: some View {
        let layout = compact ? AnyLayout(HStackLayout(spacing: 3)) : AnyLayout(VStackLayout(spacing: 2))
        layout {
            Image(systemName: weather.symbolName)
                .font(.caption)
                .symbolRenderingMode(.multicolor)
            if weather.precipitationChance > 0 {
                let chance = weather.precipitationChance
                Text(DewPointFormatters.percent(chance))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WeatherForecastValues: View {
    let day: WeatherDashboardDay
    let metric: WeatherForecastMetric
    let scale: WeatherRangeScale
    let current: Double?
    let usesFixedColumns: Bool

    var body: some View {
        HStack(spacing: 6) {
            if let low = metric.low(day), let high = metric.high(day), low.isFinite, high.isFinite {
                Text(degrees(low))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: usesFixedColumns ? 32 : nil, alignment: .trailing)
                    .layoutPriority(1)
                WeatherRangeBar(low: low, high: high, scale: scale,
                                colors: [metric.color(low), metric.color(high)], current: current)
                    .frame(minWidth: 24)
                Text(degrees(high))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(width: usesFixedColumns ? 32 : nil, alignment: .trailing)
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
    let errorMessage: String?
    var compact = false

    var body: some View {
        let layout = compact ? AnyLayout(HStackLayout(spacing: 12))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        layout {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack(spacing: 8) {
                if isLoading { ProgressView().controlSize(.small) }
                Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt, timeZone: reading.forecastCalendar.timeZone, includesDate: !reading.forecastCalendar.isDate(reading.fetchedAt, inSameDayAs: Date())))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Link("Data from \(DewPointConfiguration.appleWeatherTrademark)", destination: DewPointConfiguration.appleWeatherLegalAttributionURL)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Weather data from \(DewPointConfiguration.appleWeatherTrademark). Opens legal attribution.")
        }
    }
}
#endif
