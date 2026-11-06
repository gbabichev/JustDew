import Foundation

/// Layout decisions for the app dashboard. Widgets and watchOS have their own hosts.
/// Views consume resolved styles rather than combining platform and density flags.
struct WeatherLayoutPolicy: Equatable, Sendable {
    enum Platform: Sendable {
        case mobile, desktop

        static var current: Self {
            #if os(macOS)
            .desktop
            #else
            .mobile
            #endif
        }

        var readingSize: CGFloat { self == .desktop ? 32 : 36 }
    }

    enum Presentation: Sendable { case standard, foldedBook, foldedTabletop }
    enum NavigationMode { case compact, splitCollapsed, splitExpanded }
    enum ForecastArrangement { case stacked, adaptiveColumns }
    enum FoldedArrangement { case accessibleStack, matchedStack, columns }

    enum CardSpacing: Sendable {
        case regular, compact
        var padding: CGFloat { self == .compact ? 12 : 14 }
        var gap: CGFloat { self == .compact ? 6 : 10 }
    }

    enum ForecastRowStyle: Sendable {
        case compact, roomy, accessible
        var conditionWidth: CGFloat { self == .roomy ? 66 : 54 }
        var symbolWidth: CGFloat { self == .roomy ? 24 : 18 }
        var precipitationWidth: CGFloat { self == .roomy ? 36 : 30 }
        var valueWidth: CGFloat { self == .roomy ? 40 : 32 }
    }

    enum ForecastStyle: Sendable {
        case compact, roomy, desktop, foldedBook, accessible

        var metrics: ForecastMetrics {
            switch self {
            case .compact: .init(cardSpacing: .compact, rowStyle: .compact, rowGap: 3, rowHeight: 18, showsExplanation: false)
            case .roomy: .init(cardSpacing: .regular, rowStyle: .roomy, rowGap: 6, rowHeight: 28, showsExplanation: false)
            case .desktop: .init(cardSpacing: .compact, rowStyle: .compact, rowGap: 4, rowHeight: 22, showsExplanation: false)
            case .foldedBook: .init(cardSpacing: .regular, rowStyle: .compact, rowGap: 3, rowHeight: 20, showsExplanation: false)
            case .accessible: .init(cardSpacing: .regular, rowStyle: .accessible, rowGap: 6, rowHeight: 26, showsExplanation: true)
            }
        }
    }

    struct ForecastMetrics: Sendable {
        let cardSpacing: CardSpacing
        let rowStyle: ForecastRowStyle
        let rowGap: CGFloat
        let rowHeight: CGFloat
        let showsExplanation: Bool
    }

    // ViewThatFits remains the final authority on whether two cards actually fit.
    static let minimumColumnWidth: CGFloat = 320
    static let columnGap: CGFloat = 12
    static let stackedCardGap: CGFloat = 10
    static let maximumContentWidth: CGFloat = 1_100
    static let sidebarWidth: ClosedRange<CGFloat> = 230...320
    static let idealSidebarWidth: CGFloat = 270

    static func navigationMode(for width: CGFloat, isPartiallyFolded: Bool = false) -> NavigationMode {
        // A sidebar would consume the usable region on one side of the hinge.
        // Use the native location sheet until the display is fully open again.
        if isPartiallyFolded { return .compact }
        if width >= 1_050 { return .splitExpanded }
        if width >= 760 { return .splitCollapsed }
        return .compact
    }

    let platform: Platform
    let presentation: Presentation
    let accessibility: Bool
    let forecastStyle: ForecastStyle
    let forecastArrangement: ForecastArrangement
    let foldedArrangement: FoldedArrangement
    let outerGap: CGFloat
    let contentPadding: CGFloat
    let bottomPadding: CGFloat

    init(platform: Platform = .current, viewport: CGSize? = nil, regularWidth: Bool = false,
         accessibility: Bool = false, presentation: Presentation = .standard) {
        self.platform = platform
        self.presentation = presentation
        self.accessibility = accessibility
        let landscape = viewport.map { $0.width > $0.height } ?? false
        let heightConstrained = !accessibility && landscape && (viewport?.width ?? 0) >= 700

        // Accessibility wins first, then the physical folded presentation, then platform/space.
        if accessibility {
            forecastStyle = .accessible
        } else {
            switch presentation {
            case .foldedBook: forecastStyle = .foldedBook
            case .foldedTabletop: forecastStyle = .compact
            case .standard:
                forecastStyle = platform == .desktop ? .desktop : (regularWidth ? .roomy : .compact)
            }
        }
        forecastArrangement = !accessibility && (platform == .desktop || landscape) ? .adaptiveColumns : .stacked
        foldedArrangement = accessibility ? .accessibleStack : (presentation == .foldedTabletop ? .columns : .matchedStack)
        outerGap = platform == .desktop ? 12 : (heightConstrained ? 14 : 16)
        contentPadding = platform == .desktop || heightConstrained ? 12 : 14
        bottomPadding = heightConstrained ? 4 : (platform == .desktop ? 12 : 16)
    }

    var defaultCardSpacing: CardSpacing { platform == .desktop && !accessibility ? .compact : .regular }
    var dashboardGap: CGFloat { platform == .desktop ? 12 : Self.stackedCardGap }
    var footerInline: Bool { presentation == .standard && !accessibility }
    var accessibilityCardGap: CGFloat { 16 }
    var foldedContentGap: CGFloat { 16 }
    var foldedContentPadding: CGFloat { 14 }
    func usesCompactComfort(spacing: CardSpacing?) -> Bool {
        spacing == .compact || platform == .desktop
    }
    var foldedCardGap: CGFloat {
        switch foldedArrangement {
        case .matchedStack: 14
        case .columns, .accessibleStack: 16
        }
    }
}
