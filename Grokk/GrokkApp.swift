//
//  GrokkApp.swift
//  Grokk
//
//  Created by Артем Ярыгин on 10.02.2026.
//

import SwiftUI

#if os(macOS)
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first?.makeKeyAndOrderFront(self)
        }
        return true
    }

    @objc private func handleStatusItemLeftClick() {
        let app = NSApplication.shared
        app.unhide(nil)
        app.activate(ignoringOtherApps: true)

        if let window = app.windows.first {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else { return }

        button.target = self
        button.action = #selector(handleStatusItemLeftClick)
        button.sendAction(on: [.leftMouseUp])

        if let image = NSImage(named: "tray") {
            image.size = NSSize(width: 18, height: 18)
            button.image = image
        } else {
            button.title = "G"
        }

        statusItem = item
    }
}
#endif

@main
struct GrokkApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        #if os(macOS)
        Window("Grokk", id: "main") {
            ContentView()
        }
        #else
        WindowGroup {
            ContentView()
        }
        #endif
    }
}
