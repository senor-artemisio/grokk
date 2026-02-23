//
//  GrokkApp.swift
//  Grokk
//
//  Created by Артем Ярыгин on 10.02.2026.
//

import SwiftUI

#if os(macOS)
import AppKit
import WebKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let statusItemMenu = NSMenu()
    private var proxySettingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupStatusItemMenu()
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

    @objc private func handleStatusItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusItem?.menu = statusItemMenu
            statusItem?.button?.performClick(nil)
            return
        }

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
    }

    @objc private func handleHomeMenuItem() {
        guard let url = URL(string: "https://grok.com") else { return }
        WebViewStore.shared.webView.load(URLRequest(url: url))
    }

    @objc private func handleReloadMenuItem() {
        WebViewStore.shared.webView.reload()
    }

    @objc private func handleProxySettingsMenuItem() {
        showProxySettingsWindow()
    }

    private func showProxySettingsWindow() {
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
        #else
        WindowGroup {
            ContentView()
        }
        #endif
    }
}
