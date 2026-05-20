import SwiftUI
import WidgetKit

#if os(iOS) || os(macOS)
struct DewPointWidgetEntry: TimelineEntry {
    let date: Date
    let reading: DewPointReading?
    let message: String?
}

extension DewPointWidgetEntry {
    static var previewReading: DewPointWidgetEntry {
        DewPointWidgetEntry(date: .now, reading: DewPointWidgetLoader.sampleReading, message: nil)
    }

    static var previewNeedsLocation: DewPointWidgetEntry {
        DewPointWidgetEntry(date: .now, reading: nil, message: "Choose Location")
    }
}

struct JustDewWidgetEntryView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: DewPointWidgetEntry
    private let familyOverride: WidgetFamily?

    init(entry: DewPointWidgetEntry, family: WidgetFamily? = nil) {
        self.entry = entry
        familyOverride = family
    }

    var body: some View {
        Group {
            if let reading = entry.reading {
                content(for: reading)
            } else {
                unavailableContent
            }
        }
        #if os(macOS)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        #endif
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var family: WidgetFamily {
        familyOverride ?? environmentFamily
    }

    private var contentAlignment: Alignment {
        switch family {
        #if os(iOS)
        case .accessoryCircular:
            .center
        #endif
        case .accessoryInline:
            .center
        default:
            .topLeading
        }
    }

    @ViewBuilder
    private func content(for reading: DewPointReading) -> some View {
        switch family {
        #if os(iOS)
        case .accessoryInline:
            Text("Dew \(DewPointFormatters.temperature(reading.dewPoint)) \(DewPointFormatters.updatedTime(reading.fetchedAt))")
                .foregroundStyle(primaryTextColor)
        case .accessoryCircular:
            VStack(spacing: 2) {
                Image(systemName: "drop.degreesign.fill")
                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.caption.bold())
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(primaryTextColor)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Dew Point")
                    .font(.caption2)
                    .foregroundStyle(secondaryTextColor)
                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(primaryTextColor)
                Text(reading.location.widgetDisplayName)
                    .font(.caption2)
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)
                Text(DewPointFormatters.updatedTime(reading.fetchedAt))
                    .font(.caption2)
                    .foregroundStyle(secondaryTextColor)
            }
        #endif
        case .systemMedium, .systemLarge, .systemExtraLarge:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "drop.degreesign.fill")
                            .foregroundStyle(comfortAccentColor(for: reading))
                        Text("Dew Point")
                            .foregroundStyle(secondaryTextColor)
                    }
                    Spacer()
                    Image(systemName: reading.symbolName)
                        .foregroundStyle(secondaryTextColor)
                }
                .font(.subheadline)

                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(dewPointValueColor(for: reading))

                Text(reading.location.widgetDisplayName)
                    .font(.subheadline)
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(1)

                HStack {
                    Text("Air \(DewPointFormatters.temperature(reading.temperature))")
                    Text("Humidity \(DewPointFormatters.percent(reading.humidity))")
                    Spacer()
                    Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt))")
                }
                .font(.caption)
                .foregroundStyle(secondaryTextColor)

                Spacer(minLength: 0)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "drop.degreesign.fill")
                        .foregroundStyle(comfortAccentColor(for: reading))
                    Text("Dew Point")
                        .foregroundStyle(secondaryTextColor)
                }
                .font(.caption)
                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(dewPointValueColor(for: reading))
                HStack(spacing: 8) {
                    Label(DewPointFormatters.temperature(reading.temperature), systemImage: "thermometer.medium")
                    Label(DewPointFormatters.percent(reading.humidity), systemImage: "humidity.fill")
                }
                .font(.caption2)
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                Text(reading.location.widgetDisplayName)
                    .font(.caption2)
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(2)
                Text("Updated \(DewPointFormatters.updatedTime(reading.fetchedAt))")
                    .font(.caption2)
                    .foregroundStyle(tertiaryTextColor)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
    }

    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "drop.degreesign")
                .font(.title3)
            Text(entry.message ?? "Choose Location")
                .font(.caption)
                .lineLimit(3)
        }
        .foregroundStyle(secondaryTextColor)
    }

    private var primaryTextColor: Color {
        #if os(macOS)
        macTextColor(opacity: renderingMode == .vibrant ? 0.96 : 0.88)
        #else
        Color.primary
        #endif
    }

    private var secondaryTextColor: Color {
        #if os(macOS)
        macTextColor(opacity: renderingMode == .vibrant ? 0.78 : 0.62)
        #else
        Color.secondary
        #endif
    }

    private var tertiaryTextColor: Color {
        #if os(macOS)
        macTextColor(opacity: renderingMode == .vibrant ? 0.68 : 0.44)
        #else
        Color.secondary
        #endif
    }

    private func macTextColor(opacity: Double) -> Color {
        Color.black.opacity(opacity)
    }

    private func dewPointValueColor(for reading: DewPointReading) -> Color {
        showsComfortColor ? comfortColor(for: reading) : primaryTextColor
    }

    private func comfortAccentColor(for reading: DewPointReading) -> Color {
        showsComfortColor ? comfortColor(for: reading) : secondaryTextColor
    }

    private var showsComfortColor: Bool {
        #if os(macOS)
        renderingMode == .fullColor
        #else
        true
        #endif
    }

    private func comfortColor(for reading: DewPointReading) -> Color {
        DewPointComfortScale.color(for: reading.dewPointCelsius)
    }
}
#endif

#if os(watchOS)
struct WatchDewPointEntry: TimelineEntry {
    let date: Date
    let reading: DewPointReading?
    let message: String?
}

extension WatchDewPointEntry {
    static var previewReading: WatchDewPointEntry {
        WatchDewPointEntry(date: .now, reading: DewPointWidgetLoader.sampleReading, message: nil)
    }

    static var previewNeedsLocation: WatchDewPointEntry {
        WatchDewPointEntry(date: .now, reading: nil, message: "Choose Location")
    }
}

struct JustDewWatchEntryView: View {
    @Environment(\.widgetFamily) private var environmentFamily

    let entry: WatchDewPointEntry
    private let familyOverride: WidgetFamily?

    init(entry: WatchDewPointEntry, family: WidgetFamily? = nil) {
        self.entry = entry
        familyOverride = family
    }

    var body: some View {
        Group {
            if let reading = entry.reading {
                content(for: reading)
            } else {
                unavailableContent
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var family: WidgetFamily {
        familyOverride ?? environmentFamily
    }

    @ViewBuilder
    private func content(for reading: DewPointReading) -> some View {
        switch family {
        case .accessoryInline:
            Text("Dew \(DewPointFormatters.temperature(reading.dewPoint)) \(DewPointFormatters.updatedTime(reading.fetchedAt))")
        case .accessoryCircular, .accessoryCorner:
            ZStack {
                AccessoryWidgetBackground()
                DewPointComfortRing(dewPointCelsius: reading.dewPointCelsius)
                Text(DewPointFormatters.temperatureValue(reading.dewPoint))
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                VStack {
                    Spacer()
                    Image(systemName: "drop.degreesign.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(DewPointComfortScale.color(for: reading.dewPointCelsius))
                        .padding(.bottom, 2)
                }
            }
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text("Dew Point")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(DewPointFormatters.temperature(reading.dewPoint))
                    .font(.headline.monospacedDigit())
                Text(reading.location.widgetDisplayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(DewPointFormatters.updatedTime(reading.fetchedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var unavailableContent: some View {
        VStack(spacing: 3) {
            Image(systemName: "drop.degreesign")
            Text(entry.message ?? "Choose Location")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
    }
}
#endif

private struct DewPointComfortRing: View {
    let dewPointCelsius: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                DewPointComfortArcShape(progress: 1)
                    .stroke(.secondary.opacity(0.18), style: strokeStyle)

                DewPointComfortArcShape(progress: 1)
                    .stroke(
                        dewPointComfortGaugeGradient,
                        style: strokeStyle
                    )

                Circle()
                    .fill(DewPointComfortScale.color(for: dewPointCelsius))
                    .frame(width: markerSize, height: markerSize)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.8), lineWidth: 1)
                    }
                    .position(markerPosition(in: proxy.size))
            }
        }
        .padding(2)
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: 5, lineCap: .round)
    }

    private var markerSize: CGFloat {
        6
    }

    private func markerPosition(in size: CGSize) -> CGPoint {
        let inset: CGFloat = 4
        let diameter = max(min(size.width, size.height) - inset * 2, 0)
        let radius = diameter / 2
        let progress = DewPointComfortScale.progress(for: dewPointCelsius)
        let angle = (135 + 270 * progress) * .pi / 180

        return CGPoint(
            x: size.width / 2 + cos(angle) * radius,
            y: size.height / 2 + sin(angle) * radius
        )
    }
}

private struct DewPointComfortArcShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 4
        let diameter = max(min(rect.width, rect.height) - inset * 2, 0)
        let arcRect = CGRect(
            x: rect.midX - diameter / 2,
            y: rect.midY - diameter / 2,
            width: diameter,
            height: diameter
        )
        let clampedProgress = progress.clamped(to: 0...1)
        var path = Path()
        path.addArc(
            center: CGPoint(x: arcRect.midX, y: arcRect.midY),
            radius: diameter / 2,
            startAngle: .degrees(135),
            endAngle: .degrees(135 + 270 * clampedProgress),
            clockwise: false
        )
        return path
    }
}

private var dewPointComfortGaugeGradient: AngularGradient {
    AngularGradient(
        colors: DewPointComfortScale.gradientColors,
        center: .center,
        startAngle: .degrees(135),
        endAngle: .degrees(405)
    )
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
