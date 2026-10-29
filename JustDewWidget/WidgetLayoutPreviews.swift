import SwiftUI
import WidgetKit

// Select an iPhone or iPad destination in the canvas to compare native sizing.
#if DEBUG
#Preview("Dew Point · Small", as: .systemSmall) {
    JustDewWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    DewPointWidgetEntry.previewNeedsLocation
}

#Preview("Dew Point · Medium", as: .systemMedium) {
    JustDewWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    DewPointWidgetEntry.previewNeedsLocation
}

#Preview("Dew Point · Large", as: .systemLarge) {
    JustDewWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    DewPointWidgetEntry.previewNeedsLocation
}

#Preview("Weather · Small", as: .systemSmall) {
    JustWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    DewPointWidgetEntry.previewNeedsLocation
}

#Preview("Weather · Medium", as: .systemMedium) {
    JustWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    DewPointWidgetEntry.previewNeedsLocation
}

#Preview("Weather · Large", as: .systemLarge) {
    JustWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    DewPointWidgetEntry.previewNeedsLocation
}

#Preview("Combo · Small", as: .systemSmall) {
    CombinedWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    DewPointWidgetEntry.previewNeedsLocation
}

#Preview("Combo · Medium", as: .systemMedium) {
    CombinedWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    DewPointWidgetEntry.previewNeedsLocation
}

#Preview("Combo · Large", as: .systemLarge) {
    CombinedWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    DewPointWidgetEntry.previewNeedsLocation
}

private enum WidgetLayoutPreviewEntries {
    static var longLocation: DewPointWidgetEntry {
        var reading = DewPointWidgetLoader.sampleReading
        reading.location.name = "San Francisco, CA"
        return DewPointWidgetEntry(date: .now, reading: reading, message: nil)
    }

    static var freezing: DewPointWidgetEntry {
        var reading = DewPointWidgetLoader.sampleReading
        reading.dewPointCelsius = -23
        reading.temperatureCelsius = -12
        return DewPointWidgetEntry(date: .now, reading: reading, message: nil)
    }
}
#endif
