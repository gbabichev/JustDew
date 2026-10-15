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
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
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
                .frame(minWidth: 400, minHeight: 540)
                #endif
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .defaultSize(width: 1_050, height: 740)
        .windowResizability(.contentMinSize)
        .commands { JustDewAboutCommands() }
        #endif

        #if os(macOS)
        Window("About JustDew", id: "about") {
            AboutView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        #endif
    }
}
