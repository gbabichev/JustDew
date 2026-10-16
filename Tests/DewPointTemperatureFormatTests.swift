import Foundation

// Compile with SharedCore/DewPointFormatters.swift; no simulator or network needed.
@main
struct DewPointTemperatureFormatTests {
    static func main() {
        let celsius = Locale(identifier: "en_US@mu=celsius")
        let fahrenheit = Locale(identifier: "en_GB@mu=fahrenhe")
        let freezing = Measurement(value: 0, unit: UnitTemperature.celsius)
        let mild = Measurement(value: 20, unit: UnitTemperature.celsius)

        // Explicit temperature preferences must win over the region's default.
        expect(DewPointFormatters.temperature(mild, locale: celsius), "20°C")
        expect(DewPointFormatters.temperature(mild, locale: fahrenheit), "68°F")
        precondition(DewPointFormatters.temperatureValue(mild, locale: celsius) == "20")
        precondition(DewPointFormatters.temperatureValue(mild, locale: fahrenheit) == "68")
        expect(DewPointFormatters.temperatureRange(low: freezing, high: mild, locale: celsius), "0-20°C")
        expect(DewPointFormatters.temperatureRange(low: freezing, high: mild, locale: fahrenheit), "32-68°F")
        expect(DewPointFormatters.temperatureRange(low: mild, high: mild, locale: celsius), "20°C")

        // Defaults, conversions from another source unit, rounding, and negative values.
        expect(DewPointFormatters.temperature(mild, locale: Locale(identifier: "en_US")), "68°F")
        expect(DewPointFormatters.temperature(mild, locale: Locale(identifier: "en_GB")), "20°C")
        expect(DewPointFormatters.temperature(Measurement(value: 68, unit: .fahrenheit), locale: celsius), "20°C")
        expect(DewPointFormatters.temperature(Measurement(value: -5, unit: .celsius), locale: fahrenheit), "23°F")
        expect(DewPointFormatters.temperature(Measurement(value: 14.6, unit: .celsius), locale: celsius), "15°C")
        print("Temperature formatting tests passed")
    }

    private static func expect(_ actual: String, _ expected: String) {
        precondition(actual.filter { !$0.isWhitespace } == expected, "Expected \(expected), got \(actual)")
    }
}
