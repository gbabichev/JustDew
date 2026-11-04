#if os(iOS) || os(macOS)
import SwiftUI

struct DewPointComfortSummary: View {
    let reading: DewPointReading
    var compact = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let analysis = DewPointComfortAnalysis(reading: reading, referenceDate: context.date)
            Text(description(for: analysis))
                .font(compact ? .caption : .subheadline)
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
}
#endif
