//
//  JustDewApp.swift
//  JustDew
//
//  Created by George Babichev on 5/18/26.
//

import SwiftUI

#if os(macOS)
import AppKit

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    private var windowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            Self.configure(window)
        }

        for window in NSApp.windows {
            Self.configure(window)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private static func configure(_ window: NSWindow) {
        window.styleMask.remove(.miniaturizable)
        window.styleMask.remove(.resizable)

        for button in [NSWindow.ButtonType.miniaturizeButton, .zoomButton] {
            guard let windowButton = window.standardWindowButton(button) else { continue }
            windowButton.isHidden = true
            windowButton.isEnabled = false
        }
    }
}
#endif

@main
struct JustDewApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(width: 400, height: 640)
                #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 400, height: 640)
        .windowResizability(.contentSize)
        #endif
    }
}
