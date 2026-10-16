import Foundation
#if DEBUG
import OSLog
import SwiftUI
#endif

/// Local debug-build diagnostics. No coordinates or full forecast payloads.
@MainActor
enum DewPointStartupLog {
    #if DEBUG
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "JustDew", category: "StartupTrace")
    private static let session = String(UUID().uuidString.prefix(8))
    private static var sequence = 0
    #endif

    static func event(_ name: String, _ details: @autoclosure () -> String) {
        #if DEBUG
        sequence += 1
        let message = "[StartupTrace \(session) #\(sequence)] \(name) \(details())"
        logger.notice("\(message, privacy: .public)")
        #endif
    }

    static func location(_ value: DewPointLocation?) -> String {
        guard let value else { return "nil" }
        return "\(value.compactDisplayName)[\(value.mode.rawValue)]"
    }

    static func reading(_ value: DewPointReading?) -> String {
        guard let value else { return "nil" }
        return "\(location(value.location)) dewC=\(value.dewPointCelsius) airC=\(value.temperatureCelsius) observed=\(value.observedAt.formatted(.iso8601)) fetched=\(value.fetchedAt.formatted(.iso8601))"
    }

    static func selection(_ id: String?, in locations: [DewPointLocation]) -> String {
        guard let id else { return "nil" }
        guard let index = locations.firstIndex(where: { $0.id == id }) else { return "unknown page" }
        return "page[\(index)]=\(location(locations[index]))"
    }

    static func pages(_ locations: [DewPointLocation]) -> String {
        locations.enumerated().map { "\($0.offset):\(location($0.element))" }.joined(separator: ", ")
    }
}

#if DEBUG
struct DewPointPageContentTrace: ViewModifier {
    let page: DewPointLocation
    let reading: DewPointReading?
    let source: String

    func body(content: Content) -> some View {
        content.onChange(of: reading, initial: true) { _, value in
            let matches = value.map { $0.location.id == page.id } ?? true
            DewPointStartupLog.event("page.content", "page=\(DewPointStartupLog.location(page)) source=\(source) readingMatchesPage=\(matches) reading=\(DewPointStartupLog.reading(value))")
        }
    }
}
#endif
