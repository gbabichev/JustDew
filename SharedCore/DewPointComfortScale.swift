import SwiftUI

enum DewPointComfortScale {
    private static let cool = RGBColor(red: 0.16, green: 0.46, blue: 0.86)
    private static let medium = RGBColor(red: 0.96, green: 0.82, blue: 0.14)
    private static let gross = RGBColor(red: 0.88, green: 0.16, blue: 0.14)

    static let coolColor = color(from: cool)
    static let mediumColor = color(from: medium)
    static let grossColor = color(from: gross)

    static let gradientColors = [
        coolColor,
        mediumColor,
        grossColor
    ]

    static func progress(for dewPointCelsius: Double) -> Double {
        ((dewPointCelsius - 10) / 14).clamped(to: 0...1)
    }

    static func color(for dewPointCelsius: Double) -> Color {
        let value = progress(for: dewPointCelsius)

        if value < 0.5 {
            return mixedColor(from: cool, to: medium, progress: value / 0.5)
        }

        return mixedColor(from: medium, to: gross, progress: (value - 0.5) / 0.5)
    }

    private static func mixedColor(from start: RGBColor, to end: RGBColor, progress: Double) -> Color {
        let value = progress.clamped(to: 0...1)

        return Color(
            red: start.red + (end.red - start.red) * value,
            green: start.green + (end.green - start.green) * value,
            blue: start.blue + (end.blue - start.blue) * value
        )
    }

    private static func color(from color: RGBColor) -> Color {
        Color(red: color.red, green: color.green, blue: color.blue)
    }
}

private struct RGBColor {
    let red: Double
    let green: Double
    let blue: Double
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
