#if os(macOS) || os(iOS)
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(iOS)
        NavigationStack {
            IOSAboutContent()
                .navigationTitle("About JustDew")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        #else
        VStack(spacing: 20) {
            AboutContent()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 24)
        .frame(width: 410)
        .onExitCommand { dismiss() }
        #endif
    }
}

#if os(iOS)
private struct IOSAboutContent: View {
    var body: some View {
        Form {
            Section {
                IOSAboutAppHeader()
                    .listRowBackground(Color.clear)
            }
            Section {
                AboutDeveloperProfile()
                    .padding(.vertical, 4)
            }
            Section {
                AboutLinks()
            } footer: {
                Text(verbatim: "© \(Calendar.current.component(.year, from: Date())) George Babichev")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
        }
    }
}

private struct IOSAboutAppHeader: View {
    var body: some View {
        HStack(spacing: 16) {
            LiveAppIconView()
            VStack(alignment: .leading, spacing: 4) {
                Text("JustDew")
                    .font(.title2.weight(.semibold))
                AboutAppDetails()
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.vertical, 4)
    }
}
#endif

private struct AboutContent: View {
    var body: some View {
        VStack(spacing: 20) {
            AboutAppHeader()
            AboutAppDetails()
            VStack(alignment: .leading, spacing: 16) {
                AboutDeveloperProfile()
                Divider()
                AboutLinks()
            }
            .padding(16)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
        }
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

    #if os(iOS)
    private var appIcon: UIImage? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primaryIcon["CFBundleIconFiles"] as? [String],
              let name = files.last else { return nil }
        return UIImage(named: name)
    }
    #endif

    var body: some View {
        Group {
            #if os(macOS)
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
            #else
            if let icon = appIcon {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "drop.degreesign.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.cyan)
            }
            #endif
        }
            .id(refreshID)
            .frame(width: 72, height: 72)
            #if os(iOS)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            #endif
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
        String(localized: "Development")
        #elseif WEB_RELEASE
        String(localized: "Web Release")
        #else
        String(localized: "App Store")
        #endif
    }

    var body: some View {
        #if os(iOS)
        LabeledContent("Version", value: appVersion)
        LabeledContent("Build", value: appBuild)
        #else
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
        #endif
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

private struct AboutLinks: View {
    var body: some View {
        VStack(spacing: 14) {
            Link(destination: URL(string: "https://gbabichev.github.io/JustDew/")!) {
                HStack {
                    Text("Learn more about JustDew")
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .accessibilityHidden(true)
                }
            }
            Link(destination: URL(string: "https://georgebabichev.com/#projects")!) {
                HStack {
                    Text("Explore my apps")
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .accessibilityHidden(true)
                }
            }
        }
        .font(.callout)
    }
}

private struct AboutDeveloperProfile: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AboutDeveloperPhoto()
                VStack(alignment: .leading, spacing: 4) {
                    Text("George Babichev")
                        .font(.headline)
                    Text("Meet the developer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Text("I build focused, native apps for Mac, iPhone, and iPad.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AboutDeveloperPhoto: View {
    var body: some View {
        Group {
            #if os(macOS)
            let photo = NSImage(named: "gbabichev").map { Image(nsImage: $0) }
            #else
            let photo = UIImage(named: "gbabichev").map { Image(uiImage: $0) }
            #endif
            if let photo {
                photo
                    .resizable()
                    .scaledToFill()
                    .offset(y: 4)
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

#if os(macOS)
private struct AboutPresentationKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var showsJustDewAbout: Binding<Bool>? {
        get { self[AboutPresentationKey.self] }
        set { self[AboutPresentationKey.self] = newValue }
    }
}

struct MacAboutPresentation: ViewModifier {
    // Read and written through $showsAbout by the sheet and focused scene binding.
    // periphery:ignore
    @State private var showsAbout = false

    func body(content: Content) -> some View {
        content
            .focusedSceneValue(\.showsJustDewAbout, $showsAbout)
            .sheet(isPresented: $showsAbout) {
                AboutView()
            }
    }
}

struct JustDewAboutCommands: Commands {
    @FocusedBinding(\.showsJustDewAbout) private var showsAbout

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About JustDew") { showsAbout = true }
                .disabled(showsAbout == nil)
        }
    }
}
#endif

#endif
