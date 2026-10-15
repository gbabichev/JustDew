#if os(iOS)
import SwiftUI
import UIKit

/// Apply margins to this page's navigation bar without changing global appearance
/// or insetting the scroll view's full-screen background and scroll-edge effect.
struct DewPointNavigationBarMargins: UIViewControllerRepresentable {
    let horizontal: CGFloat

    func makeUIViewController(context: Context) -> MarginController {
        MarginController(horizontal: horizontal)
    }

    func updateUIViewController(_ controller: MarginController, context: Context) {
        controller.horizontal = horizontal
        controller.applyMargins()
    }

    final class MarginController: UIViewController {
        var horizontal: CGFloat

        init(horizontal: CGFloat) {
            self.horizontal = horizontal
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            applyMargins()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            applyMargins()
        }

        func applyMargins() {
            guard let bar = navigationController?.navigationBar else { return }
            var margins = bar.directionalLayoutMargins
            guard margins.leading != horizontal || margins.trailing != horizontal else { return }
            margins.leading = horizontal
            margins.trailing = horizontal
            bar.directionalLayoutMargins = margins
        }
    }
}
#endif
