#if os(watchOS)
import SwiftUI
import WidgetKit

struct CombinedWeatherWatchEntryView: View {
    let entry: WatchDewPointEntry

    var body: some View {
        Group {
            if let reading = entry.reading {
                HStack(alignment: .top, spacing: 8) {
                    WatchRectangularMetric(reading: reading, metric: .dewPoint)
                    WatchRectangularMetric(reading: reading, metric: .temperature)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                Image(systemName: "location.slash")
                    .accessibilityLabel(entry.message ?? String(localized: "Choose Location"))
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct WatchRectangularMetric: View {
    let reading: DewPointReading
    let metric: DayTimelineMetric
    var showsTitle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: metric == .dewPoint ? metric.widgetSymbol : reading.symbolName)
                    .font(.caption)
                    .accessibilityHidden(true)
                if showsTitle {
                    Text(metric.widgetTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                }
                Text(DewPointFormatters.temperature(metric.currentValue(in: reading)))
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .monospacedDigit()
            }
            .foregroundStyle(metric.color(forCelsius: metric.currentValue(in: reading).value))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(metric.widgetTitle))
            .accessibilityValue(DewPointFormatters.temperature(metric.currentValue(in: reading)))
            if let range = metric.widgetDayRange(for: reading) {
                Gauge(value: WeatherRangeScale(values: [range.lowerBound, range.upperBound])
                    .fraction(for: metric.currentValue(in: reading).value), in: 0...1) {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinear)
                .tint(Gradient(colors: [metric.color(forCelsius: range.lowerBound),
                                       metric.color(forCelsius: range.upperBound)]))
                .accessibilityHidden(true)
            } else {
                DewPointDayTimelineView(reading: reading, showsLabels: false, trackHeight: 4,
                                        markerSize: 7, metric: metric)
            }
            WidgetDayRangeText(reading: reading, metric: metric)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#endif
