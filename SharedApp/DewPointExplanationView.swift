#if os(iOS) || os(macOS)
import SwiftUI

/// Both the info icon and the reading use this same native presentation.
struct DewPointExplanationButton<Label: View>: View {
    @ViewBuilder var label: Label
    @State private var showsExplanation = false

    var body: some View {
        Button {
            showsExplanation = true
        } label: {
            label
        }
        .buttonStyle(.plain)
        .accessibilityHint("Explains dew point, humidity, and the comfort colors")
        .popover(isPresented: $showsExplanation) {
            DewPointExplanationView()
                .presentationCompactAdaptation(.sheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct DewPointExplanationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    DewPointExplanationLegend()
                    DewPointHumidityExplanation()
                    DewPointComfortLimitExplanation()
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Understanding Dew Point")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(idealWidth: 400, idealHeight: 600)
    }
}

private struct DewPointExplanationLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What the colors mean")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("Higher dew points mean more moisture in the air and generally feel muggier.")
                .font(.subheadline)
            Capsule()
                .fill(LinearGradient(colors: DewPointComfortScale.gradientColors,
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 10)
                .accessibilityHidden(true)
            DewPointLegendRow(title: "Blue · lower moisture",
                range: "≤ \(temperature(DewPointComfortScale.lowerBoundCelsius))",
                low: DewPointComfortScale.lowerBoundCelsius, high: DewPointComfortScale.lowerBoundCelsius)
            DewPointLegendRow(title: "Blue to yellow · increasing moisture",
                range: range(DewPointComfortScale.lowerBoundCelsius, DewPointComfortScale.midpointCelsius),
                low: DewPointComfortScale.lowerBoundCelsius, high: DewPointComfortScale.midpointCelsius)
            DewPointLegendRow(title: "Yellow to red · high moisture",
                range: range(DewPointComfortScale.midpointCelsius, DewPointComfortScale.upperBoundCelsius),
                low: DewPointComfortScale.midpointCelsius, high: DewPointComfortScale.upperBoundCelsius)
            DewPointLegendRow(title: "Red · very high moisture",
                range: "≥ \(temperature(DewPointComfortScale.upperBoundCelsius))",
                low: DewPointComfortScale.upperBoundCelsius, high: DewPointComfortScale.upperBoundCelsius)
            Text("Colors blend gradually across this scale; they are not hard comfort cutoffs.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func temperature(_ value: Double) -> String {
        DewPointFormatters.temperature(Measurement(value: value, unit: .celsius))
    }

    private func range(_ low: Double, _ high: Double) -> String {
        DewPointFormatters.temperatureRange(low: Measurement(value: low, unit: .celsius),
                                            high: Measurement(value: high, unit: .celsius))
    }
}

private struct DewPointLegendRow: View {
    let title: LocalizedStringKey
    let range: String
    let low: Double
    let high: Double

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [DewPointComfortScale.color(for: low), DewPointComfortScale.color(for: high)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 28, height: 14)
                .padding(.top, 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(range).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DewPointHumidityExplanation: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dew point vs. humidity")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("Dew point is the temperature at which air becomes saturated. It helps describe how much moisture is in the air.")
            Text("Relative humidity tells you how close the air is to saturation at its current temperature. The same humidity percentage can feel different on a cool day and a hot day.")
        }
        .font(.subheadline)
    }
}

private struct DewPointComfortLimitExplanation: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your comfortable hours")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("Choose your dew point limit in the Comfortable hours today menu. Changing that limit changes the hours shown, but keeps the color scale the same.")
            Text("These comfort descriptions refer to moisture, rather than temperature, rain, or wind.")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}
#endif
