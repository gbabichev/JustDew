import SwiftUI
import WidgetKit

struct WeatherWatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "JustDewWatchWeatherWidget", provider: WatchDewPointProvider()) { entry in
            JustDewWatchEntryView(entry: entry, metric: .temperature)
        }
        .configurationDisplayName("Weather")
        .description("Weather for your current location.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

#Preview(as: .accessoryCircular) {
    WeatherWatchWidget()
} timeline: {
    WatchDewPointEntry.previewReading
}

#Preview(as: .accessoryRectangular) {
    WeatherWatchWidget()
} timeline: {
    WatchDewPointEntry.previewReading
}
