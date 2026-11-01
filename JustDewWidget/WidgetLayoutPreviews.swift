import SwiftUI
import WidgetKit

// Select an iPhone or iPad destination in the canvas to compare native sizing.
// Use the canvas timeline entries to exercise long names, negative readings, and dark mode.
// For a single contact sheet across size proposals: zsh tools/render-widget-gallery.zsh
#if DEBUG
#Preview("Dew Point · Small", as: .systemSmall) {
    JustDewWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    WidgetLayoutPreviewEntries.hotAndDark
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
    SavedLocationWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    WidgetLayoutPreviewEntries.hotAndDark
    DewPointWidgetEntry.previewNeedsLocation
}

#Preview("Weather · Medium", as: .systemMedium) {
    SavedLocationWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    DewPointWidgetEntry.previewNeedsLocation
}

#Preview("Weather · Large", as: .systemLarge) {
    SavedLocationWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    DewPointWidgetEntry.previewNeedsLocation
}

#Preview("Combo · Small", as: .systemSmall) {
    SavedLocationCombinedWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    WidgetLayoutPreviewEntries.hotAndDark
    DewPointWidgetEntry.previewNeedsLocation
}

#Preview("Combo · Medium", as: .systemMedium) {
    SavedLocationCombinedWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    DewPointWidgetEntry.previewNeedsLocation
}

#Preview("Combo · Large", as: .systemLarge) {
    SavedLocationCombinedWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    WidgetLayoutPreviewEntries.freezing
    DewPointWidgetEntry.previewNeedsLocation
}

#Preview("Dew Point · Extra Large", as: .systemExtraLarge) {
    JustDewWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
}

#Preview("Weather · Extra Large", as: .systemExtraLarge) {
    SavedLocationWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.freezing
}

#Preview("Combo · Extra Large", as: .systemExtraLarge) {
    SavedLocationCombinedWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
}

@available(iOS 27.0, macOS 27.0, *)
#Preview("Dew Point · Extra Large Portrait", as: .systemExtraLargePortrait) {
    JustDewWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    DewPointWidgetEntry.previewNeedsLocation
}

@available(iOS 27.0, macOS 27.0, *)
#Preview("Weather · Extra Large Portrait", as: .systemExtraLargePortrait) {
    SavedLocationWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.freezing
    DewPointWidgetEntry.previewNeedsLocation
}

@available(iOS 27.0, macOS 27.0, *)
#Preview("Combo · Extra Large Portrait", as: .systemExtraLargePortrait) {
    SavedLocationCombinedWeatherWidget()
} timeline: {
    DewPointWidgetEntry.previewReading
    WidgetLayoutPreviewEntries.longLocation
    DewPointWidgetEntry.previewNeedsLocation
}

private enum WidgetLayoutPreviewEntries {
    static var longLocation: DewPointWidgetEntry {
        var reading = DewPointWidgetLoader.sampleReading
        reading.location.name = "San Francisco, CA"
        reading.location.shortName = nil
        return DewPointWidgetEntry(date: .now, reading: reading, message: nil)
    }

    static var freezing: DewPointWidgetEntry {
        var reading = DewPointWidgetLoader.sampleReading
        reading.dewPointCelsius = -23
        reading.temperatureCelsius = -12
        return DewPointWidgetEntry(date: .now, reading: reading, message: nil)
    }

    static var hotAndDark: DewPointWidgetEntry {
        var reading = DewPointWidgetLoader.sampleReading
        reading.dewPointCelsius = 27
        reading.temperatureCelsius = 40
        return DewPointWidgetEntry(date: .now, reading: reading, message: nil, alwaysDark: true)
    }
}
#endif
