// Developer-only visual regression gallery. Not a member of any app target.
import SwiftUI
import WidgetKit
import ImageIO
import UniformTypeIdentifiers

private struct LayoutCase {
    let name: String
    let width: CGFloat
    let height: CGFloat
    let family: WidgetFamily
}

private struct GalleryWidget: View {
    let entry: DewPointWidgetEntry
    let kind: String
    let family: WidgetFamily

    var body: some View {
        if kind == "Combo" {
            CombinedWeatherWidgetEntryView(entry: entry, family: family)
        } else {
            JustDewWidgetEntryView(entry: entry, family: family,
                                  metric: kind == "Dew Point" ? .dewPoint : .temperature)
        }
    }
}

@main
private struct WidgetLayoutGallery {
    @MainActor
    static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        // These are layout stress proposals, not device detection or production sizes.
        // Include the Mini's observed 120/260-point effective Home Screen dimensions.
        // Standalone ImageRenderer has no WidgetKit host, so supply a 16-point inset.
        let cases: [LayoutCase] = [
            .init(name: "Small · compact / Mini stress", width: 120, height: 120, family: .systemSmall),
            .init(name: "Small · standard", width: 148, height: 148, family: .systemSmall),
            .init(name: "Small · roomy", width: 170, height: 170, family: .systemSmall),
            .init(name: "Medium · compact", width: 260, height: 120, family: .systemMedium),
            .init(name: "Medium · standard", width: 320, height: 148, family: .systemMedium),
            .init(name: "Medium · roomy", width: 364, height: 170, family: .systemMedium),
            .init(name: "Large · compact", width: 260, height: 260, family: .systemLarge),
            .init(name: "Large · standard", width: 320, height: 320, family: .systemLarge),
            .init(name: "Large · roomy", width: 364, height: 364, family: .systemLarge),
            .init(name: "Extra Large · wide", width: 540, height: 260, family: .systemExtraLarge),
            .init(name: "Extra Large · portrait", width: 320, height: 500, family: .systemExtraLargePortrait)
        ]
        let kinds = ["Dew Point", "Weather", "Combo"]
        let fixtures = ["Typical", "Cold / long name", "Hot / dark"]
        var html = """
        <!doctype html><html lang="en"><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>JustDew widget layout gallery</title>
        <style>
        body{font:15px system-ui;margin:24px;background:#e9e9ee;color:#222}
        h2{margin-top:40px}table{border-collapse:collapse}th,td{padding:12px;vertical-align:top;text-align:left}
        td{border:1px solid #ccc}img{display:block}small{color:#555}a{color:#0069b5}
        .scroll{overflow-x:auto}figure{margin:0}figcaption{padding-top:5px}
        </style><h1>JustDew widget layout gallery</h1>
        <p>Real widget view code, rendered at 2×. Images display at point size. Scroll horizontally for wide cases.</p>
        <p><strong>Visual stress checks, not native device screenshots.</strong> Standalone renders emulate 16-point margins;
        WidgetKit also applies device-specific margins, font traits, and scaling. Confirm release layouts in the native
        <code>WidgetLayoutPreviews.swift</code> canvas using the desired destination.</p>
        <p>Check: single-line temperatures, visible headers and timestamps, readable ranges, and content inside the blue border.</p>
        """
        for (fixtureIndex, fixture) in fixtures.enumerated() {
            var reading = DewPointWidgetLoader.sampleReading
            if fixtureIndex == 1 {
                reading.location.name = "Rancho Santa Margarita, CA"
                reading.location.shortName = nil
                reading.dewPointCelsius = -23
                reading.temperatureCelsius = -12
            } else if fixtureIndex == 2 {
                reading.dewPointCelsius = 27
                reading.temperatureCelsius = 40
            }
            let entry = DewPointWidgetEntry(date: reading.fetchedAt, reading: reading, message: nil)
            html += "<h2>\(fixture)</h2><div class='scroll'><table><thead><tr><th>Proposed size</th>"
            html += kinds.map { "<th>\($0)</th>" }.joined() + "</tr></thead><tbody>"
            for (caseIndex, layout) in cases.enumerated() {
                html += "<tr><th>\(layout.name)<br><small>\(Int(layout.width)) × \(Int(layout.height)) pt</small></th>"
                for (kindIndex, kind) in kinds.enumerated() {
                    let filename = "\(fixtureIndex)-\(caseIndex)-\(kindIndex).png"
                    let dark = fixtureIndex == 2
                    let view = GalleryWidget(entry: entry, kind: kind, family: layout.family)
                        .padding(16)
                        .frame(width: layout.width, height: layout.height, alignment: .topLeading)
                        .background(dark ? Color.black : Color.white)
                        .overlay(Rectangle().stroke(Color.blue.opacity(0.6), lineWidth: 1))
                        // Leave overflow visible so a bad layout is apparent in the contact sheet.
                        .padding(18)
                        .background(dark ? Color(white: 0.2) : Color(white: 0.85))
                        .environment(\.colorScheme, dark ? .dark : .light)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 2
                    guard let image = renderer.cgImage,
                          let destination = CGImageDestinationCreateWithURL(
                            output.appendingPathComponent(filename) as CFURL,
                            UTType.png.identifier as CFString, 1, nil) else {
                        fatalError("Could not render \(filename)")
                    }
                    CGImageDestinationAddImage(destination, image, nil)
                    guard CGImageDestinationFinalize(destination) else { fatalError("Could not save \(filename)") }
                    html += "<td><img src='\(filename)' width='\(Int(layout.width + 36))' alt='\(kind), \(layout.name), \(fixture)'></td>"
                }
                html += "</tr>"
            }
            html += "</tbody></table></div>"
        }
        html += "</html>"
        try html.write(to: output.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        print("Rendered \(cases.count * kinds.count * fixtures.count) widget layouts.")
    }
}
