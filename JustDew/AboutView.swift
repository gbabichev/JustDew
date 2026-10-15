#if os(macOS)
import AppKit
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            AboutAppHeader()
            AboutAppDetails()
            AboutDeveloperProfile()
            Divider()
            Text("JustDew keeps dew point, comfort ranges, and forecasts close at hand, with saved locations and widgets for Mac, iPhone, and Apple Watch.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 330)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 24)
        .frame(width: 410)
    }
}

private struct AboutAppHeader: View {
    var body: some View {
        VStack(spacing: 10) {
            LiveAppIconView()
            Text("JustDew")
                .font(.title.weight(.semibold))
            Text("A little clarity about the air around you.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)
        }
    }
}

private struct LiveAppIconView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var refreshID = UUID()

    var body: some View {
        Group {
            if let icon = NSApp?.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "drop.degreesign.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.cyan)
            }
        }
            .id(refreshID)
            .frame(width: 72, height: 72)
            .accessibilityHidden(true)
            .onChange(of: colorScheme) { _, _ in
                // Let AppKit update the icon's appearance before reading it again.
                DispatchQueue.main.async { refreshID = UUID() }
            }
    }
}

private struct AboutAppDetails: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
    }

    private var releaseChannel: String {
        #if DEBUG
        "Development"
        #elseif WEB_RELEASE
        "Web Release"
        #else
        "App Store"
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AboutRow(label: "Version", value: appVersion)
            AboutRow(label: "Build", value: appBuild)
            AboutRow(label: "Release Channel", value: releaseChannel)
            AboutRow(label: "Developer", value: "George Babichev")
            AboutRow(label: "Copyright", value: "© \(Calendar.current.component(.year, from: Date())) George Babichev")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        }
    }
}

private struct AboutRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AboutDeveloperProfile: View {
    var body: some View {
        HStack(spacing: 12) {
            AboutDeveloperPhoto()
            VStack(alignment: .leading, spacing: 4) {
                Text("George Babichev").font(.headline)
                Link(destination: URL(string: "https://georgebabichev.com")!) {
                    HStack(spacing: 4) {
                        Text("georgebabichev.com")
                        Image(systemName: "arrow.up.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.subheadline)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AboutDeveloperPhoto: View {
    var body: some View {
        Group {
            // Add the supplied portrait as an image asset named "gbabichev".
            if let photo = NSImage(named: "gbabichev") {
                Image(nsImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

struct JustDewAboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About JustDew") { openWindow(id: "about") }
        }
    }
}
#endif
