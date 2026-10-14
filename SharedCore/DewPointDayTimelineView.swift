import SwiftUI

struct DewPointDayTimelineView: View {
    var reading: DewPointReading
    var showsLabels = true
    var trackHeight: CGFloat = 7
    var markerSize: CGFloat = 14
    var usesComfortColor = true
    var monochromeColor: Color = .secondary

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
                    HStack(alignment: .top, spacing: 8) {
                        axisLabel(for: dayStart, alignment: .leading)
                        axisLabel(for: midday, alignment: .center)
                        axisLabel(for: lateEvening, alignment: .trailing)
                    }
                    .font(.caption2)
                    .foregroundStyle(monochromeColor.opacity(0.75))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Today's dew point")
            .accessibilityValue("Now \(DewPointFormatters.temperature(reading.dewPoint))")
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
                            monochromeColor: monochromeColor
                        ),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: trackHeight)
                    .position(x: width / 2, y: centerY)

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
        .frame(height: max(trackHeight, markerSize))
    }

    private func axisLabel(for date: Date, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(DewPointFormatters.hourLabel(date))

            if let forecastPoint = forecastPoint(nearest: date) {
                Text(DewPointFormatters.temperature(forecastPoint.dewPoint))
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment(for: alignment))
    }

    private var dayStart: Date {
        Calendar.current.startOfDay(for: reading.observedAt)
    }

    private var dayEnd: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
    }

    private var midday: Date {
        Calendar.current.date(byAdding: .hour, value: 12, to: dayStart) ?? dayStart.addingTimeInterval(43_200)
    }

    private var lateEvening: Date {
        Calendar.current.date(byAdding: .hour, value: 23, to: dayStart) ?? dayEnd.addingTimeInterval(-3_600)
    }

    private var markerColor: Color {
        usesComfortColor ? DewPointComfortScale.color(for: reading.dewPointCelsius) : monochromeColor
    }

    private func forecastPoint(nearest date: Date) -> DewPointForecastPoint? {
        forecastPoints.min {
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
    var monochromeColor: Color = .secondary

    private var forecastDays: [DewPointForecastDay] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: reading.observedAt)

        return (1..<DewPointConfiguration.forecastDayCount).compactMap { dayOffset in
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
            VStack(alignment: .leading, spacing: 8) {
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
            Text(DewPointFormatters.weekdayLabel(day.dayStart))
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
            Text(DewPointFormatters.weekdayLabel(day.dayStart))
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
                            end: day.dayEnd
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
    monochromeColor: Color = .secondary
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
            ? DewPointComfortScale.color(for: point.dewPointCelsius)
            : monochromeColor.opacity(0.45)
    }
    let location: (Date) -> CGFloat = { date in
        let progress = date.timeIntervalSince(start) / duration
        return CGFloat(min(max(progress, 0), 1))
    }

    return (
        [Gradient.Stop(color: color(firstPoint), location: 0)]
        + sortedPoints.map { point in
            Gradient.Stop(color: color(point), location: location(point.date))
        }
        + [Gradient.Stop(color: color(lastPoint), location: 1)]
    )
    .sorted { $0.location < $1.location }
}
