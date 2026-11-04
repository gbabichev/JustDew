import SwiftUI

/// Native weather colors, with cloud layers that remain visible on light backgrounds.
struct WeatherConditionSymbolStyle: ViewModifier {
    let symbolName: String
    var usesColor = true
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if !usesColor {
            content.symbolRenderingMode(.monochrome)
        } else if symbolName.contains("cloud") {
            content
                .symbolVariant(.fill)
                .symbolRenderingMode(.palette)
                .foregroundStyle(colorScheme == .dark ? Color.white : Color.gray,
                                 cloudAccent, Color.cyan)
        } else {
            content
                .symbolVariant(.fill)
                .symbolRenderingMode(.multicolor)
        }
    }

    private var cloudAccent: Color {
        if symbolName.contains("sun") || symbolName.contains("moon") || symbolName.contains("bolt") {
            return .yellow
        }
        if symbolName.contains("rain") || symbolName.contains("drizzle")
            || symbolName.contains("snow") || symbolName.contains("sleet") || symbolName.contains("hail") {
            return .cyan
        }
        return .gray
    }
}
