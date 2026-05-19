import SwiftUI
import WidgetKit

private struct WatchWidgetPreviewTile<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(8)
            .frame(width: width, height: height)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding()
    }
}

struct JustDewWatchWidgetPreviewHost: PreviewProvider {
    static var previews: some View {
        Group {
            WatchWidgetPreviewTile(width: 74, height: 74) {
                JustDewWatchEntryView(entry: .previewReading, family: .accessoryCircular)
            }
                .previewDisplayName("Circular")

            WatchWidgetPreviewTile(width: 172, height: 72) {
                JustDewWatchEntryView(entry: .previewReading, family: .accessoryRectangular)
            }
                .previewDisplayName("Rectangular")

            WatchWidgetPreviewTile(width: 190, height: 36) {
                JustDewWatchEntryView(entry: .previewReading, family: .accessoryInline)
            }
                .previewDisplayName("Inline")

            WatchWidgetPreviewTile(width: 74, height: 74) {
                JustDewWatchEntryView(entry: .previewReading, family: .accessoryCorner)
            }
                .previewDisplayName("Corner")

            WatchWidgetPreviewTile(width: 172, height: 72) {
                JustDewWatchEntryView(entry: .previewNeedsLocation, family: .accessoryRectangular)
            }
                .previewDisplayName("Needs Location")
        }
    }
}
