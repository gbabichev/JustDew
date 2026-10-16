//
//  JustDewWatch.swift
//  JustDewWatch
//
//  Created by George Babichev on 5/18/26.
//

import WidgetKit
import SwiftUI

struct WatchDewPointProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchDewPointEntry {
        WatchDewPointEntry(date: Date(), reading: DewPointWidgetLoader.sampleReading, message: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchDewPointEntry) -> Void) {
        if context.isPreview {
            completion(WatchDewPointEntry(date: Date(), reading: DewPointWidgetLoader.sampleReading, message: nil))
            return
        }

        Task {
            completion(await makeEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchDewPointEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            let nextUpdate = Date().addingTimeInterval(DewPointConfiguration.refreshInterval)
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func makeEntry() async -> WatchDewPointEntry {
        do {
            let reading = try await DewPointWidgetLoader.loadReading()
            return WatchDewPointEntry(date: Date(), reading: reading, message: nil)
        } catch {
            let cachedReading = DewPointWidgetLoader.cachedReading(locationID: "current")
            return WatchDewPointEntry(date: Date(), reading: cachedReading, message: error.dewPointDisplayMessage)
        }
    }
}

struct JustDewWatch: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DewPointConfiguration.watchWidgetKind, provider: WatchDewPointProvider()) { entry in
            JustDewWatchEntryView(entry: entry)
        }
        .configurationDisplayName("Dew Point · Current Location")
        .description("Shows the dew point at your current location, wherever you go.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
