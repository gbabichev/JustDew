import Foundation

/// Moisture comfort only: this does not classify temperature, wind, or rain.
struct DewPointComfortAnalysis {
    enum Condition {
        case dry, humid, muggy, unavailable
    }

    let condition: Condition
    let isRecent: Bool

    init(reading: DewPointReading, referenceDate: Date = .now) {
        let calendar = reading.forecastCalendar
        let age = referenceDate.timeIntervalSince(reading.observedAt)
        isRecent = age >= -300 && age <= 5_400 && calendar.isDate(reading.observedAt, inSameDayAs: referenceDate)
        if !reading.dewPointCelsius.isFinite {
            condition = .unavailable
        } else if reading.dewPointCelsius <= Measurement(value: 55, unit: UnitTemperature.fahrenheit).converted(to: .celsius).value {
            condition = .dry
        } else if reading.dewPointCelsius < Measurement(value: 65, unit: UnitTemperature.fahrenheit).converted(to: .celsius).value {
            condition = .humid
        } else {
            condition = .muggy
        }
    }
}
