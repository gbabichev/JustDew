#if os(iOS) || os(macOS)
import SwiftUI

private let comfortLimitKey = "dewPointComfortLimitFahrenheit"

struct DewPointComfortSummary: View {
    let reading: DewPointReading
    var compact = false
    @AppStorage(comfortLimitKey) private var storedLimit = DewPointComfortLimit.standard.rawValue

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let analysis = DewPointComfortAnalysis(reading: reading,
                limit: DewPointComfortLimit(rawValue: storedLimit) ?? .standard, referenceDate: context.date)
            VStack(alignment: .leading, spacing: 2) {
                Text(description(for: analysis))
                    .font(compact ? .caption : .subheadline)
                if !compact {
                    outlook(for: analysis)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func description(for analysis: DewPointComfortAnalysis) -> LocalizedStringResource {
        switch (analysis.condition, analysis.isRecent) {
        case (.dry, true): "Dry and comfortable now."
        case (.dry, false): "Dry and comfortable at the last update."
        case (.humid, true): "Some humidity in the air now."
        case (.humid, false): "Some humidity at the last update."
        case (.muggy, true): "Muggy now."
        case (.muggy, false): "Muggy at the last update."
        case (.unavailable, _): "Dew point comfort is unavailable."
        }
    }

    @ViewBuilder
    private func outlook(for analysis: DewPointComfortAnalysis) -> some View {
        if let first = analysis.windows.first {
            if first.start == analysis.referenceDate {
                if first.end == analysis.dayEnd {
                    Text("Within your comfort limit through midnight.")
                } else {
                    Text("Within your comfort limit until about \(time(first.end)).")
                }
            } else {
                Text("Below your comfort limit around \(time(first.start)).")
            }
        } else if analysis.hasCompleteCoverage {
            Text("Above your comfort limit for the rest of today.")
        }
    }

    private func time(_ date: Date) -> String {
        DewPointFormatters.updatedTime(date, timeZone: reading.forecastCalendar.timeZone)
    }
}

struct DewPointComfortHours: View {
    let reading: DewPointReading
    var compact = false
    @AppStorage(comfortLimitKey) private var storedLimit = DewPointComfortLimit.standard.rawValue

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let limit = DewPointComfortLimit(rawValue: storedLimit) ?? .standard
            let analysis = DewPointComfortAnalysis(reading: reading, limit: limit, referenceDate: context.date)
            VStack(alignment: .leading, spacing: compact ? 3 : 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Comfortable hours today")
                        .font(.caption.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    Menu {
                        Picker("Dew point limit", selection: $storedLimit) {
                            ForEach(DewPointComfortLimit.allCases) { option in
                                Text("At or below \(DewPointFormatters.temperature(option.temperature))")
                                    .tag(option.rawValue)
                            }
                        }
                    } label: {
                        Text("≤ \(DewPointFormatters.temperature(limit.temperature))")
                    }
                    .font(.caption)
                    #if os(macOS)
                    .menuStyle(.borderlessButton)
                    .controlSize(.small)
                    .fixedSize()
                    .foregroundStyle(.secondary)
                    #endif
                    .accessibilityLabel("Change dew point comfort limit")
                    .accessibilityValue(DewPointFormatters.temperature(limit.temperature))
                }
                DewPointComfortWindows(reading: reading, analysis: analysis)
                    .font(compact ? .caption2 : .caption)
                if !compact {
                    Text("Remaining today · based on dew point only")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DewPointComfortWindows: View {
    let reading: DewPointReading
    let analysis: DewPointComfortAnalysis

    var body: some View {
        if analysis.windows.isEmpty {
            if analysis.hasHourlyForecast {
                Text("No hours within your limit in the available forecast.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Hourly comfort forecast is unavailable.")
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(Array(analysis.windows.prefix(2)), id: \.start) { window in
                windowLabel(window)
            }
            if analysis.windows.count > 2 {
                DisclosureGroup("More comfortable hours") {
                    ForEach(Array(analysis.windows.dropFirst(2)), id: \.start) { window in
                        windowLabel(window)
                    }
                }
            }
        }
    }

    private func windowLabel(_ window: DateInterval) -> Text {
        let start = window.start == analysis.referenceDate
            ? String(localized: "Now") : time(window.start)
        let end = window.end == analysis.dayEnd
            ? String(localized: "Midnight") : time(window.end)
        return Text("\(start) – \(end)")
    }

    private func time(_ date: Date) -> String {
        DewPointFormatters.updatedTime(date, timeZone: reading.forecastCalendar.timeZone)
    }
}
#endif
