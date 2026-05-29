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

    private var segments: [DewPointTimelineSegment] {
        let points = forecastPoints

        return points.indices.compactMap { index in
            let point = points[index]
            let start: Date
            let end: Date

            if index == points.startIndex {
                start = dayStart
            } else {
                start = midpoint(points[index - 1].date, point.date)
            }

            if index == points.index(before: points.endIndex) {
                end = dayEnd
            } else {
                end = midpoint(point.date, points[index + 1].date)
            }

            guard end > start else { return nil }

            return DewPointTimelineSegment(
                id: point.date,
                start: start,
                end: end,
                dewPointCelsius: point.dewPointCelsius
            )
        }
    }

    var body: some View {
        if !segments.isEmpty {
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
                    .fill(monochromeColor.opacity(0.18))
                    .frame(height: trackHeight)
                    .position(x: width / 2, y: centerY)

                ForEach(segments) { segment in
                    let startX = xPosition(for: segment.start, width: width)
                    let endX = xPosition(for: segment.end, width: width)
                    let segmentWidth = max(endX - startX, 2)

                    Capsule(style: .continuous)
                        .fill(segmentColor(for: segment.dewPointCelsius))
                        .frame(width: segmentWidth, height: trackHeight)
                        .position(x: startX + segmentWidth / 2, y: centerY)
                }

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

    private func segmentColor(for dewPointCelsius: Double) -> Color {
        usesComfortColor ? DewPointComfortScale.color(for: dewPointCelsius) : monochromeColor.opacity(0.45)
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

    private func midpoint(_ start: Date, _ end: Date) -> Date {
        start.addingTimeInterval(end.timeIntervalSince(start) / 2)
    }
}

struct DewPointWeekForecastView: View {
    var reading: DewPointReading
    var trackHeight: CGFloat = 7
    var monochromeColor: Color = .secondary

    private var forecastDays: [DewPointForecastDay] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: reading.observedAt)

        return (1...5).compactMap { dayOffset in
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
                    .fill(monochromeColor.opacity(0.18))
                    .frame(height: trackHeight)
                    .position(x: width / 2, y: centerY)

                ForEach(day.segments) { segment in
                    let startX = xPosition(for: segment.start, in: day, width: width)
                    let endX = xPosition(for: segment.end, in: day, width: width)
                    let segmentWidth = max(endX - startX, 2)

                    Capsule(style: .continuous)
                        .fill(DewPointComfortScale.color(for: segment.dewPointCelsius))
                        .frame(width: segmentWidth, height: trackHeight)
                        .position(x: startX + segmentWidth / 2, y: centerY)
                }
            }
        }
        .frame(height: trackHeight)
    }

    private func xPosition(for date: Date, in day: DewPointForecastDay, width: CGFloat) -> CGFloat {
        let duration = day.dayEnd.timeIntervalSince(day.dayStart)
        guard duration > 0 else { return 0 }

        let progress = date.timeIntervalSince(day.dayStart) / duration
        return width * min(max(progress, 0), 1)
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

    var segments: [DewPointTimelineSegment] {
        points.indices.compactMap { index in
            let point = points[index]
            let start: Date
            let end: Date

            if index == points.startIndex {
                start = dayStart
            } else {
                start = midpoint(points[index - 1].date, point.date)
            }

            if index == points.index(before: points.endIndex) {
                end = dayEnd
            } else {
                end = midpoint(point.date, points[index + 1].date)
            }

            guard end > start else { return nil }

            return DewPointTimelineSegment(
                id: point.date,
                start: start,
                end: end,
                dewPointCelsius: point.dewPointCelsius
            )
        }
    }

    private func midpoint(_ start: Date, _ end: Date) -> Date {
        start.addingTimeInterval(end.timeIntervalSince(start) / 2)
    }
}

private struct DewPointTimelineSegment: Identifiable {
    var id: Date
    var start: Date
    var end: Date
    var dewPointCelsius: Double
}
