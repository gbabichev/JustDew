#if os(iOS)
import SwiftUI
import UIKit

/// Use the system page indicator, including its native taps and accessibility.
struct DewPointPageControl: UIViewRepresentable {
    let locationIDs: [String]
    @Binding var selectedID: String?

    func makeUIView(context: Context) -> UIPageControl {
        let control = UIPageControl()
        control.backgroundStyle = .prominent
        control.accessibilityLabel = String(localized: "Saved Locations")
        control.addTarget(context.coordinator, action: #selector(Coordinator.selectPage(_:)),
                          for: .valueChanged)
        return control
    }

    func updateUIView(_ control: UIPageControl, context: Context) {
        context.coordinator.parent = self
        control.numberOfPages = locationIDs.count
        control.currentPage = locationIDs.firstIndex(where: { $0 == selectedID }) ?? 0
        control.isEnabled = context.environment.isEnabled
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIPageControl, context: Context) -> CGSize? {
        uiView.size(forNumberOfPages: locationIDs.count)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject {
        var parent: DewPointPageControl

        init(parent: DewPointPageControl) {
            self.parent = parent
        }

        @objc func selectPage(_ control: UIPageControl) {
            guard parent.locationIDs.indices.contains(control.currentPage) else { return }
            withAnimation {
                parent.selectedID = parent.locationIDs[control.currentPage]
            }
        }
    }
}
#endif
