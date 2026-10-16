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

struct JustDewWidgetPreviewHost: PreviewProvider {
    static var previews: some View {
        Group {
            WidgetPreviewTile(width: 160, height: 160) {
                JustDewWidgetEntryView(entry: .previewReading, family: .systemSmall)
            }
                .previewDisplayName("Small")

            WidgetPreviewTile(width: 360, height: 170) {
                JustDewWidgetEntryView(entry: .previewReading, family: .systemMedium)
            }
                .previewDisplayName("Medium")

            #if !os(macOS)
            WidgetPreviewTile(width: 84, height: 84) {
                JustDewWidgetEntryView(entry: .previewReading, family: .accessoryCircular)
            }
                .previewDisplayName("Lock Screen Circular")

            WidgetPreviewTile(width: 172, height: 72) {
                JustDewWidgetEntryView(entry: .previewReading, family: .accessoryRectangular)
            }
                .previewDisplayName("Lock Screen Rectangular")

            WidgetPreviewTile(width: 220, height: 40) {
                JustDewWidgetEntryView(entry: .previewReading, family: .accessoryInline)
            }
                .previewDisplayName("Lock Screen Inline")
            #endif

            WidgetPreviewTile(width: 160, height: 160) {
                JustDewWidgetEntryView(entry: .previewNeedsLocation, family: .systemSmall)
            }
                .previewDisplayName("Needs Location")
        }
    }
}

struct WeatherWidgetPreviewHost: PreviewProvider {
    static var previews: some View {
        Group {
            WidgetPreviewTile(width: 160, height: 160) {
                JustDewWidgetEntryView(entry: .previewReading, family: .systemSmall, metric: .temperature)
            }.previewDisplayName("Weather Small")
            WidgetPreviewTile(width: 360, height: 170) {
                JustDewWidgetEntryView(entry: .previewReading, family: .systemMedium, metric: .temperature)
            }.previewDisplayName("Weather Medium")
            WidgetPreviewTile(width: 360, height: 360) {
                JustDewWidgetEntryView(entry: .previewReading, family: .systemLarge, metric: .temperature)
            }.previewDisplayName("Weather Large")
            #if os(iOS)
            WidgetPreviewTile(width: 84, height: 84) {
                JustDewWidgetEntryView(entry: .previewReading, family: .accessoryCircular, metric: .temperature)
            }.previewDisplayName("Weather Circular")
            WidgetPreviewTile(width: 172, height: 72) {
                JustDewWidgetEntryView(entry: .previewReading, family: .accessoryRectangular, metric: .temperature)
            }.previewDisplayName("Weather Rectangular")
            WidgetPreviewTile(width: 220, height: 40) {
                JustDewWidgetEntryView(entry: .previewReading, family: .accessoryInline, metric: .temperature)
            }.previewDisplayName("Weather Inline")
            #endif
        }
    }
}

struct CombinedWidgetPreviewHost: PreviewProvider {
    static var previews: some View {
        Group {
            WidgetPreviewTile(width: 160, height: 160) {
                CombinedWeatherWidgetEntryView(entry: .previewReading, family: .systemSmall)
            }.previewDisplayName("Combined Small")
            WidgetPreviewTile(width: 360, height: 170) {
                CombinedWeatherWidgetEntryView(entry: .previewReading, family: .systemMedium)
            }.previewDisplayName("Combined Medium")
            WidgetPreviewTile(width: 360, height: 360) {
                CombinedWeatherWidgetEntryView(entry: .previewReading, family: .systemLarge)
            }.previewDisplayName("Combined Large")
            WidgetPreviewTile(width: 160, height: 160) {
                CombinedWeatherWidgetEntryView(entry: DewPointWidgetEntry(date: .now,
                    reading: DewPointWidgetLoader.sampleReading, message: nil, alwaysDark: true), family: .systemSmall)
            }.previewDisplayName("Combined Always Dark")
            WidgetPreviewTile(width: 160, height: 160) {
                CombinedWeatherWidgetEntryView(entry: .previewNeedsLocation, family: .systemSmall)
            }.previewDisplayName("Combined Needs Location")
        }
    }
}
