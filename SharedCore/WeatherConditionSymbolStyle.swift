import SwiftUI

/// Weather colors with readable cloud and moon layers on light backgrounds.
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
        } else if symbolName.contains("moon") {
            content
                .symbolVariant(.fill)
                .symbolRenderingMode(.palette)
                .foregroundStyle(moonColor, moonColor)
        } else {
            content
                .symbolVariant(.fill)
                .symbolRenderingMode(.multicolor)
        }
    }

    private var cloudAccent: Color {
        if symbolName.contains("moon") { return moonColor }
        if symbolName.contains("sun") || symbolName.contains("bolt") {
            return .yellow
        }
        if symbolName.contains("rain") || symbolName.contains("drizzle")
            || symbolName.contains("snow") || symbolName.contains("sleet") || symbolName.contains("hail") {
            return .cyan
        }
        return .gray
    }

    private var moonColor: Color {
        colorScheme == .dark ? .yellow : .indigo
    }
}
