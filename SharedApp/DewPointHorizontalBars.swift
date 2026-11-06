#if os(iOS)
import SwiftUI

/// Keep system status and navigation bars horizontal on the weather dashboard.
struct DewPointHorizontalBars: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.toolbarVerticalBehavior(.disabled)
        } else {
            content
        }
    }
}
#endif
