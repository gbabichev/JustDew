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
