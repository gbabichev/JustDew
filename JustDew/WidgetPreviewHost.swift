import SwiftUI
import WidgetKit

private struct WidgetPreviewTile<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(width: width, height: height)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(radius: 12, y: 4)
            .padding()
    }
}

// Home Screen previews live in JustDewWidget/WidgetLayoutPreviews.swift so WidgetKit supplies margins.
#if os(iOS)
struct JustDewWidgetPreviewHost: PreviewProvider {
    static var previews: some View {
        Group {
            WidgetPreviewTile(width: 62, height: 62) {
                JustDewWidgetEntryView(entry: .previewReading, family: .accessoryCircular)
            }.previewDisplayName("Lock Screen Circular")
            WidgetPreviewTile(width: 160, height: 60) {
                JustDewWidgetEntryView(entry: .previewReading, family: .accessoryRectangular)
            }.previewDisplayName("Lock Screen Rectangular")
            WidgetPreviewTile(width: 260, height: 26) {
                JustDewWidgetEntryView(entry: .previewReading, family: .accessoryInline)
            }.previewDisplayName("Lock Screen Inline")
        }
    }
}

struct WeatherWidgetPreviewHost: PreviewProvider {
    static var previews: some View {
        Group {
            WidgetPreviewTile(width: 62, height: 62) {
                JustDewWidgetEntryView(entry: .previewReading, family: .accessoryCircular, metric: .temperature)
            }.previewDisplayName("Lock Screen Circular")
            WidgetPreviewTile(width: 160, height: 60) {
                JustDewWidgetEntryView(entry: .previewReading, family: .accessoryRectangular, metric: .temperature)
            }.previewDisplayName("Lock Screen Rectangular")
            WidgetPreviewTile(width: 260, height: 26) {
                JustDewWidgetEntryView(entry: .previewReading, family: .accessoryInline, metric: .temperature)
            }.previewDisplayName("Lock Screen Inline")
        }
    }
}

struct CombinedWidgetPreviewHost: PreviewProvider {
    static var previews: some View {
        Group {
            WidgetPreviewTile(width: 62, height: 62) {
                CombinedWeatherWidgetEntryView(entry: .previewReading, family: .accessoryCircular)
            }.previewDisplayName("Lock Screen Circular")
            WidgetPreviewTile(width: 160, height: 60) {
                CombinedWeatherWidgetEntryView(entry: .previewReading, family: .accessoryRectangular)
            }.previewDisplayName("Lock Screen Rectangular")
            WidgetPreviewTile(width: 260, height: 26) {
                CombinedWeatherWidgetEntryView(entry: .previewReading, family: .accessoryInline)
            }.previewDisplayName("Lock Screen Inline")
        }
    }
}

#endif
