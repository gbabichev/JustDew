import SwiftUI
import WidgetKit

struct CombinedWeatherWatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "JustDewWatchCombinedWeatherWidget", provider: WatchDewPointProvider()) { entry in
            CombinedWeatherWatchEntryView(entry: entry)
        }
        .configurationDisplayName("Dew Point + Weather")
        .description("Dew point and weather for your current location.")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    CombinedWeatherWatchWidget()
} timeline: {
    WatchDewPointEntry.previewReading
}
