import SwiftUI

struct DewPointDayTimelineView: View {
    var reading: DewPointReading
    var showsLabels = true
    var trackHeight: CGFloat = 7
    var markerSize: CGFloat = 14
    var usesComfortColor = true
    var monochromeColor: Color = .secondary
    var referenceDate: Date? = nil
    var metric: DayTimelineMetric = .dewPoint
    @ScaledMetric(relativeTo: .caption2) private var axisLabelWidth: CGFloat = 48
    @ScaledMetric(relativeTo: .caption2) private var axisLabelsHeight: CGFloat = 30

    private var forecastPoints: [DewPointForecastPoint] {
        reading.dailyForecastPoints
            .filter { $0.date >= dayStart && $0.date < dayEnd }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        if !forecastPoints.isEmpty {
            VStack(alignment: .leading, spacing: showsLabels ? 4 : 0) {
                if showsLabels {
                    Text("Today")
                    .font(.caption2)
                    .foregroundStyle(monochromeColor)
                }

                timelineTrack

                if showsLabels {
                    GeometryReader { geometry in
                        let width = max(geometry.size.width, 1)
                        let labelWidth = min(axisLabelWidth, width)
                        let dates = axisDates(for: width)
                        ForEach(dates, id: \.self) { date in
                            axisLabel(for: date, alignment: dates.count == 1 ? .center : (date == dates.first ? .leading
                                      : (date == dates.last ? .trailing : .center))
                            )
                                .frame(width: labelWidth)
                                .position(x: min(max(xPosition(for: date, width: width), labelWidth / 2),
                                                 width - labelWidth / 2),
                                          y: geometry.size.height / 2)
                        }
                    }
                    .frame(height: axisLabelsHeight)
                    .font(.caption2)
                    .foregroundStyle(monochromeColor.opacity(0.75))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(metric == .dewPoint ? Text("Today's dew point") : Text("Today's temperature"))
            .accessibilityValue("Now \(DewPointFormatters.temperature(metric.currentValue(in: reading)))")
        }
    }

    private var timelineTrack: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let centerY = proxy.size.height / 2
            let markerX = xPosition(for: reading.observedAt, width: width)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(LinearGradient(
                        stops: timelineGradientStops(
                            for: forecastPoints,
                            start: dayStart,
                            end: dayEnd,
                            usesComfortColor: usesComfortColor,
                            monochromeColor: monochromeColor,
                            metric: metric
                        ),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: trackHeight)
                    .position(x: width / 2, y: centerY)

                if reading.observedAt >= dayStart && reading.observedAt < dayEnd {
                    Circle()
                        .fill(markerColor)
                        .frame(width: markerSize, height: markerSize)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.9), lineWidth: max(markerSize * 0.16, 1.5))
                        }
                        .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                        .position(x: markerX, y: centerY)
                }
            }
        }
        .frame(height: max(trackHeight, markerSize))
    }

    private func axisLabel(for date: Date, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(DewPointFormatters.hourLabel(date, timeZone: reading.forecastCalendar.timeZone))

            if let forecastPoint = forecastPoint(nearest: date) {
                Text(DewPointFormatters.temperature(metric.forecastValue(in: forecastPoint)))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            } else {
                Text("—")
            }
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, alignment: frameAlignment(for: alignment))
    }

    private var dayStart: Date {
        reading.forecastCalendar.startOfDay(for: referenceDate ?? reading.observedAt)
    }

    private var dayEnd: Date {
        reading.forecastCalendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
    }

    private func axisDates(for width: CGFloat) -> [Date] {
        let hours: [Int]
        if width >= axisLabelWidth * 10 {
            hours = [0, 4, 8, 12, 16, 20, 23]
        } else if width >= axisLabelWidth * 6 {
            hours = [0, 6, 12, 18, 23]
        } else if width >= axisLabelWidth * 3 {
            hours = [0, 12, 23]
        } else if width >= axisLabelWidth * 2 {
            hours = [0, 23]
        } else {
            hours = [12]
        }
        return hours.compactMap {
            reading.forecastCalendar.date(bySettingHour: $0, minute: 0, second: 0, of: dayStart)
        }
    }

    private var markerColor: Color {
        usesComfortColor ? metric.color(forCelsius: metric.currentValue(in: reading).value) : monochromeColor
    }

    private func forecastPoint(nearest date: Date) -> DewPointForecastPoint? {
        guard let first = forecastPoints.first, let last = forecastPoints.last,
              date >= first.date.addingTimeInterval(-1_800),
              date <= last.date.addingTimeInterval(3_600) else { return nil }
        return forecastPoints.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }

    private func frameAlignment(for horizontalAlignment: HorizontalAlignment) -> Alignment {
        switch horizontalAlignment {
        case .leading:
            .leading
        case .trailing:
            .trailing
        default:
            .center
        }
    }

    private func xPosition(for date: Date, width: CGFloat) -> CGFloat {
        let duration = dayEnd.timeIntervalSince(dayStart)
        guard duration > 0 else { return 0 }

        let progress = date.timeIntervalSince(dayStart) / duration
        return width * min(max(progress, 0), 1)
    }
}

struct DewPointForecastView: View {
    var reading: DewPointReading
    var trackHeight: CGFloat = 7
    var maximumDayCount = DewPointConfiguration.forecastDayCount - 1
    var rowSpacing: CGFloat = 8
    var usesComfortColor = true
    var monochromeColor: Color = .secondary

    private var forecastDays: [DewPointForecastDay] {
        let calendar = reading.forecastCalendar
        let todayStart = calendar.startOfDay(for: reading.observedAt)

        let count = min(max(maximumDayCount, 0), DewPointConfiguration.forecastDayCount - 1)
        return (1..<(count + 1)).compactMap { dayOffset in
            guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: todayStart),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return nil
            }

            let points = reading.dailyForecastPoints
                .filter { $0.date >= dayStart && $0.date < dayEnd }
                .sorted { $0.date < $1.date }

            guard !points.isEmpty else { return nil }

            return DewPointForecastDay(
                dayStart: dayStart,
                dayEnd: dayEnd,
                points: points
            )
        }
    }

    var body: some View {
        if !forecastDays.isEmpty {
            VStack(alignment: .leading, spacing: rowSpacing) {
                ForEach(forecastDays) { day in
                    dayRow(for: day)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private func dayRow(for day: DewPointForecastDay) -> some View {
        #if os(watchOS)
        VStack(alignment: .leading, spacing: 4) {
            forecastDayHeader(for: day)
            forecastTrack(for: day)
        }
        #else
        HStack(spacing: 10) {
            Text(DewPointFormatters.weekdayLabel(day.dayStart, calendar: reading.forecastCalendar))
                .font(.caption)
                .foregroundStyle(monochromeColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 72, alignment: .leading)

            forecastTrack(for: day)

            rangeText(for: day)
                .frame(width: 66, alignment: .trailing)
        }
        #endif
    }

    private func forecastDayHeader(for day: DewPointForecastDay) -> some View {
        HStack(spacing: 8) {
            Text(DewPointFormatters.weekdayLabel(day.dayStart, calendar: reading.forecastCalendar))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 6)

            rangeText(for: day)
        }
        .font(.caption2)
        .foregroundStyle(monochromeColor)
    }

    private func rangeText(for day: DewPointForecastDay) -> some View {
        Text(DewPointFormatters.temperatureRange(
            low: Measurement(value: day.lowDewPointCelsius, unit: .celsius),
            high: Measurement(value: day.highDewPointCelsius, unit: .celsius)
        ))
        .font(.caption2.weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(monochromeColor)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private func forecastTrack(for day: DewPointForecastDay) -> some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let centerY = proxy.size.height / 2

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(LinearGradient(
                        stops: timelineGradientStops(
                            for: day.points,
                            start: day.dayStart,
                            end: day.dayEnd,
                            usesComfortColor: usesComfortColor,
                            monochromeColor: monochromeColor
                        ),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: trackHeight)
                    .position(x: width / 2, y: centerY)
            }
        }
        .frame(height: trackHeight)
    }
}

private struct DewPointForecastDay: Identifiable {
    var dayStart: Date
    var dayEnd: Date
    var points: [DewPointForecastPoint]

    var id: Date {
        dayStart
    }

    var lowDewPointCelsius: Double {
        points.map(\.dewPointCelsius).min() ?? 0
    }

    var highDewPointCelsius: Double {
        points.map(\.dewPointCelsius).max() ?? lowDewPointCelsius
    }
}

private func timelineGradientStops(
    for points: [DewPointForecastPoint],
    start: Date,
    end: Date,
    usesComfortColor: Bool = true,
    monochromeColor: Color = .secondary,
    metric: DayTimelineMetric = .dewPoint
) -> [Gradient.Stop] {
    let sortedPoints = points.sorted { $0.date < $1.date }
    let inactiveColor = monochromeColor.opacity(0.18)

    guard let firstPoint = sortedPoints.first, let lastPoint = sortedPoints.last else {
        return [
            Gradient.Stop(color: inactiveColor, location: 0),
            Gradient.Stop(color: inactiveColor, location: 1)
        ]
    }

    let duration = max(end.timeIntervalSince(start), 1)
    let color: (DewPointForecastPoint) -> Color = { point in
        usesComfortColor
            ? metric.color(forCelsius: metric.forecastValue(in: point).value)
            : monochromeColor.opacity(0.45)
    }
    let location: (Date) -> CGFloat = { date in
        let progress = date.timeIntervalSince(start) / duration
        return CGFloat(min(max(progress, 0), 1))
    }

    // Extend the endpoint colors to keep the original continuous, full-day bar.
    // Axis values still require a nearby sample; extending a color isn't historical data.
    return (
        [Gradient.Stop(color: color(firstPoint), location: 0)]
        + sortedPoints.map { point in
            Gradient.Stop(color: color(point), location: location(point.date))
        }
        + [Gradient.Stop(color: color(lastPoint), location: 1)]
    )
    .sorted { $0.location < $1.location }
}

enum DayTimelineMetric: Equatable {
    case dewPoint, temperature

    func currentValue(in reading: DewPointReading) -> Measurement<UnitTemperature> {
        self == .dewPoint ? reading.dewPoint : reading.temperature
    }

    func forecastValue(in point: DewPointForecastPoint) -> Measurement<UnitTemperature> {
        self == .dewPoint ? point.dewPoint : point.temperature
    }

    func color(forCelsius value: Double) -> Color {
        self == .dewPoint ? DewPointComfortScale.color(for: value) : WeatherTemperatureColors.color(forCelsius: value)
    }
}

enum WeatherTemperatureColors {
    static func color(forCelsius value: Double) -> Color {
        switch value {
        case ..<0: return .blue
        case ..<15: return .cyan
        case ..<25: return .yellow
        case ..<32: return .orange
        default: return .red
        }
    }
}
