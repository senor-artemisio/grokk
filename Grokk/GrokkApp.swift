//
//  GrokkApp.swift
//  Grokk
//
//  Created by Артем Ярыгин on 10.02.2026.
//

import SwiftUI

#if os(macOS)
import AppKit
import Combine
import WebKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, ObservableObject {
    private var statusItem: NSStatusItem?
    private let statusItemMenu = NSMenu()
    private var proxySettingsWindow: NSWindow?
    private var hideDockMenuItem: NSMenuItem?
    private var mainWindow: NSWindow?
    private var didInitialSetup = false

    static let hideFromDockKey = "app.hideFromDock"
    @Published var hideFromDock = UserDefaults.standard.bool(forKey: AppDelegate.hideFromDockKey)

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupStatusItemMenu()
        // Don't set .accessory here — SwiftUI won't create the window.
        // We switch policy in applicationDidBecomeActive after the window exists.
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Grab main window reference and set ourselves as delegate to intercept close
        if mainWindow == nil, let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            mainWindow = window
            window.delegate = self
            window.isReleasedWhenClosed = false
        }

        // One-time: switch to accessory mode after the window is created
        if !didInitialSetup {
            didInitialSetup = true
            if hideFromDock {
                NSApp.setActivationPolicy(.accessory)
                // Re-show window since switching to accessory may hide it
                mainWindow?.makeKeyAndOrderFront(nil)
            }
        }
    }

    // MARK: NSWindowDelegate — hide instead of close

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === mainWindow {
            saveWindowFrame(sender)
            sender.orderOut(nil) // hide, don't close
            return false
        }
        return true
    }

    private static let windowFrameKey = "app.mainWindowFrame"

    private func saveWindowFrame(_ window: NSWindow) {
        let frame = window.frame
        let dict: [String: CGFloat] = ["x": frame.origin.x, "y": frame.origin.y, "w": frame.width, "h": frame.height]
        UserDefaults.standard.set(dict, forKey: Self.windowFrameKey)
    }

    private func restoreWindowFrame(_ window: NSWindow) {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.windowFrameKey),
              let x = dict["x"] as? CGFloat, let y = dict["y"] as? CGFloat,
              let w = dict["w"] as? CGFloat, let h = dict["h"] as? CGFloat else { return }
        window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let window = mainWindow {
            saveWindowFrame(window)
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    // MARK: Show main window

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        // Try existing window
        if let window = mainWindow, window.contentView != nil {
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Try to find SwiftUI-created window
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            mainWindow = window
            window.delegate = self
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            return
        }

        // SwiftUI didn't create the window — create it ourselves
        let hostingController = NSHostingController(rootView: ContentView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Grokk"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 1024, height: 768))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        restoreWindowFrame(window)

        mainWindow = window
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: Status item

    @objc private func handleStatusItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusItem?.menu = statusItemMenu
            statusItem?.button?.performClick(nil)
            return
        }
        showMainWindow()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = item.button else { return }

        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        if let image = NSImage(named: "tray") {
            image.size = NSSize(width: 18, height: 18)
            button.image = image
        } else {
            button.title = "G"
        }

        statusItem = item
    }

    // MARK: Tray menu

    private func setupStatusItemMenu() {
        statusItemMenu.delegate = self

        let homeItem = NSMenuItem(title: "Home", action: #selector(handleHomeMenuItem), keyEquivalent: "")
        homeItem.target = self
        statusItemMenu.addItem(homeItem)

        let reloadItem = NSMenuItem(title: "Reload", action: #selector(handleReloadMenuItem), keyEquivalent: "")
        reloadItem.target = self
        statusItemMenu.addItem(reloadItem)

        statusItemMenu.addItem(.separator())

        let proxyItem = NSMenuItem(title: "SOCKS5 Proxy Settings", action: #selector(handleProxySettingsMenuItem), keyEquivalent: "")
        proxyItem.target = self
        statusItemMenu.addItem(proxyItem)

        let hideDockItem = NSMenuItem(title: "Hide from Dock", action: #selector(handleHideDockMenuItem), keyEquivalent: "")
        hideDockItem.target = self
        hideDockItem.state = hideFromDock ? .on : .off
        statusItemMenu.addItem(hideDockItem)
        self.hideDockMenuItem = hideDockItem

        statusItemMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Grokk", action: #selector(handleQuitMenuItem), keyEquivalent: "q")
        quitItem.target = self
        statusItemMenu.addItem(quitItem)
    }

    @objc private func handleHomeMenuItem() {
        guard let url = URL(string: "https://grok.com") else { return }
        WebViewStore.shared.webView.load(URLRequest(url: url))
    }

    @objc private func handleReloadMenuItem() {
        WebViewStore.shared.webView.reload()
    }

    @objc private func handleProxySettingsMenuItem() {
        openProxySettings()
    }

    @objc private func handleHideDockMenuItem(_ sender: NSMenuItem) {
        setHideFromDock(!hideFromDock)
    }

    func setHideFromDock(_ hidden: Bool) {
        hideFromDock = hidden
        UserDefaults.standard.set(hidden, forKey: Self.hideFromDockKey)
        hideDockMenuItem?.state = hidden ? .on : .off
        NSApp.setActivationPolicy(hidden ? .accessory : .regular)

        if hidden {
            showMainWindow()
        }
    }

    @objc private func handleQuitMenuItem() {
        NSApp.terminate(nil)
    }

    func openProxySettings() {
        if let window = proxySettingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(rootView: ProxySettingsView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = "SOCKS5 Proxy Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 420, height: 250))
        window.isReleasedWhenClosed = false
        window.center()

        proxySettingsWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem?.menu = nil
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
        .commands {
            CommandGroup(after: .appInfo) {
                Divider()

                Button("Home") {
                    guard let url = URL(string: "https://grok.com") else { return }
                    WebViewStore.shared.webView.load(URLRequest(url: url))
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])

                Button("Reload") {
                    WebViewStore.shared.webView.reload()
                }
                .keyboardShortcut("r")

                Divider()

                Button("SOCKS5 Proxy Settings") {
                    appDelegate.openProxySettings()
                }
                .keyboardShortcut(",")

                Toggle("Hide from Dock", isOn: Binding(
                    get: { appDelegate.hideFromDock },
                    set: { appDelegate.setHideFromDock($0) }
                ))
            }

            CommandGroup(replacing: .appTermination) {
                Button("Quit Grokk") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        #else
        WindowGroup {
            ContentView()
        }
        #endif
    }
}
