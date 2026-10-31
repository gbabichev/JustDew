import AppIntents
import SwiftUI
import WidgetKit

struct JustDewWidget: Widget {
    var body: some WidgetConfiguration {
        // Keep the shipped configurable kind and intent so its saved settings survive updates.
        AppIntentConfiguration(kind: DewPointConfiguration.appWidgetKind, intent: DewPointWidgetIntent.self,
                               provider: WeatherLocationProvider<DewPointWidgetIntent>()) { entry in
            JustDewWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Dew Point")
        .description("Choose Current Location or a saved city, and optionally use an always dark appearance.")
        .supportedFamilies(WeatherWidgetFamilies.all)
        .contentMarginsDisabled()
    }
}
