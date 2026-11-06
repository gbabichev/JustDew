import Foundation

// xcrun swiftc SharedApp/WeatherLayoutPolicy.swift Tests/WeatherLayoutPolicyTests.swift -o /tmp/layout-tests
@main
struct WeatherLayoutPolicyTests {
    static func main() {
        typealias Policy = WeatherLayoutPolicy
        precondition(Policy.navigationMode(for: 759) == .compact)
        precondition(Policy.navigationMode(for: 760) == .splitCollapsed)
        precondition(Policy.navigationMode(for: 1_049) == .splitCollapsed)
        precondition(Policy.navigationMode(for: 1_050) == .splitExpanded)
        for width: CGFloat in [390, 760, 1_050, 1_366] {
            precondition(Policy.navigationMode(for: width, isPartiallyFolded: true) == .compact,
                         "Partially folded displays need the Locations sheet instead of a sidebar")
            precondition(Policy.navigationMode(for: width, isPartiallyFolded: false)
                         == Policy.navigationMode(for: width),
                         "Unfolding must restore the normal width-based navigation")
        }

        let phone = Policy(platform: .mobile, viewport: CGSize(width: 390, height: 844))
        precondition(phone.forecastArrangement == .stacked)
        precondition(phone.forecastStyle == .compact)
        let landscapePhone = Policy(platform: .mobile, viewport: CGSize(width: 740, height: 330))
        precondition(landscapePhone.forecastArrangement == .adaptiveColumns,
                     "Landscape phones must not depend on a regular horizontal size class")
        let portraitTablet = Policy(platform: .mobile, viewport: CGSize(width: 768, height: 1_024), regularWidth: true)
        precondition(portraitTablet.forecastArrangement == .stacked)
        precondition(portraitTablet.forecastStyle == .roomy)
        let landscapeTablet = Policy(platform: .mobile, viewport: CGSize(width: 1_024, height: 768), regularWidth: true)
        precondition(landscapeTablet.forecastArrangement == .adaptiveColumns)

        // Characterize the existing presentation matrix before replacing its scattered flags.
        // The expected metrics below are the previous behavior, independent of the policy implementation.
        let viewports: [CGSize?] = [nil, CGSize(width: 390, height: 844), CGSize(width: 844, height: 390),
                                   CGSize(width: 768, height: 1_024), CGSize(width: 1_024, height: 768)]
        var checked = 0
        for platform in [Policy.Platform.mobile, .desktop] {
            for viewport in viewports {
                for regularWidth in [false, true] {
                    for accessibility in [false, true] {
                        for presentation in [Policy.Presentation.standard, .foldedBook, .foldedTabletop] {
                            let layout = Policy(platform: platform, viewport: viewport, regularWidth: regularWidth,
                                                accessibility: accessibility, presentation: presentation)
                            let metrics = layout.forecastStyle.metrics
                            let expected: (Policy.ForecastStyle, CGFloat, CGFloat, Policy.CardSpacing, Policy.ForecastRowStyle)
                            if accessibility {
                                expected = (.accessible, 6, 26, .regular, .accessible)
                            } else if presentation == .foldedBook {
                                expected = (.foldedBook, 3, 20, .regular, .compact)
                            } else if presentation == .foldedTabletop {
                                expected = (.compact, 3, 18, .compact, .compact)
                            } else if platform == .desktop {
                                expected = (.desktop, 4, 22, .compact, .compact)
                            } else if regularWidth {
                                expected = (.roomy, 6, 28, .regular, .roomy)
                            } else {
                                expected = (.compact, 3, 18, .compact, .compact)
                            }
                            precondition(layout.forecastStyle == expected.0)
                            precondition(metrics.rowGap == expected.1 && metrics.rowHeight == expected.2)
                            precondition(metrics.cardSpacing == expected.3 && metrics.rowStyle == expected.4)
                            precondition(metrics.showsExplanation == accessibility)
                            precondition(layout.footerInline == (presentation == .standard && !accessibility))
                            precondition(layout.defaultCardSpacing == (platform == .desktop && !accessibility ? .compact : .regular))
                            precondition(layout.usesCompactComfort(spacing: .compact))
                            precondition(layout.usesCompactComfort(spacing: nil) == (platform == .desktop))
                            precondition(layout.usesCompactComfort(spacing: .regular) == (platform == .desktop))
                            if !accessibility {
                                precondition(layout.foldedArrangement == (presentation == .foldedTabletop ? .columns : .matchedStack))
                            }
                            if accessibility {
                                precondition(layout.forecastArrangement == .stacked)
                                precondition(layout.foldedArrangement == .accessibleStack)
                            }
                            let landscape = viewport.map { $0.width > $0.height } ?? false
                            let constrained = !accessibility && landscape && (viewport?.width ?? 0) >= 700
                            precondition(layout.contentPadding == (platform == .desktop || constrained ? 12 : 14))
                            precondition(layout.bottomPadding == (constrained ? 4 : (platform == .desktop ? 12 : 16)))
                            checked += 1
                        }
                    }
                }
            }
        }
        print("WeatherLayoutPolicy tests passed (\(checked) layout combinations and navigation boundaries)")
    }
}
