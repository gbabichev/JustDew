//
//  JustDewWidget.swift
//  JustDewWidget
//
//  Created by George Babichev on 5/18/26.
//

import WidgetKit
import SwiftUI

struct DewPointWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DewPointWidgetEntry {
        DewPointWidgetEntry(date: Date(), reading: DewPointWidgetLoader.sampleReading, message: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DewPointWidgetEntry) -> Void) {
        if context.isPreview {
            completion(DewPointWidgetEntry(date: Date(), reading: DewPointWidgetLoader.sampleReading, message: nil))
            return
        }

        Task {
            completion(await makeEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DewPointWidgetEntry>) -> Void) {
        Task {
            let entry = await makeEntry()
            let nextUpdate = Date().addingTimeInterval(DewPointConfiguration.refreshInterval)
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    private func makeEntry() async -> DewPointWidgetEntry {
        do {
            let reading = try await DewPointWidgetLoader.loadReading()
            return DewPointWidgetEntry(date: Date(), reading: reading, message: nil)
        } catch {
            let cachedReading = DewPointWidgetLoader.cachedReading(locationID: "current")
            return DewPointWidgetEntry(date: Date(), reading: cachedReading, message: error.dewPointDisplayMessage)
        }
    }
}

struct JustDewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DewPointConfiguration.appWidgetKind, provider: DewPointWidgetProvider()) { entry in
            JustDewWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Dew Point")
        .description("Shows the dew point at your current location, wherever you go.")
        #if os(macOS)
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
        #else
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
        #endif
    }
}
