import SwiftUI

/// Advance the main app's time-of-day marker without fetching new weather.
struct DewPointCurrentDayTimelineView: View {
    let reading: DewPointReading
    var trackHeight: CGFloat = 7
    var markerSize: CGFloat = 14
    var metric: DayTimelineMetric = .dewPoint

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            DewPointDayTimelineView(reading: reading, trackHeight: trackHeight, markerSize: markerSize,
                                   referenceDate: context.date, metric: metric)
        }
    }
}
