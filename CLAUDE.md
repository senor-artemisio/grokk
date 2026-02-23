# Grokk — Project Instructions

## What is this

Native macOS wrapper for [grok.com](https://grok.com). Swift 5 + SwiftUI + WebKit.

## Project Structure

```
Grokk/
  GrokkApp.swift      — App entry point, AppDelegate (tray, menus, window lifecycle, hide-from-dock)
  ContentView.swift   — WKWebView wrapper, download system (native fetch fallback, context menu), proxy logic
  ProxySettings.swift — ProxySettingsStore (singleton, UserDefaults), ProxySettingsView (SwiftUI form)
  Grokk.entitlements  — Sandbox: microphone, network client, downloads read-write
  Assets.xcassets/    — App icons (16–1024px), tray icon, accent color
```

## Architecture

- **AppDelegate** — NSApplicationDelegate + NSWindowDelegate + NSMenuDelegate + ObservableObject
  - Tray icon (NSStatusItem): left-click shows window, right-click opens menu
  - App menu (SwiftUI `.commands`): mirrors tray menu with keyboard shortcuts
  - Window management: intercepts close → hides with `orderOut` instead of destroying; fallback creation if SwiftUI doesn't restore window on launch
  - Hide from Dock: `NSApp.setActivationPolicy(.accessory/.regular)`, synced between tray and app menu via `@Published`
  - Window frame persistence: saves to UserDefaults on close/quit, restores on fallback creation
- **WebViewStore.shared** — manages single WKWebView, injects JS, observes proxy changes, requests mic permissions
- **ProxySettingsStore.shared** — proxy config, persists to UserDefaults, posts `proxySettingsDidChange` notification

## Download System

Three mechanisms:

1. **WKNavigationDelegate + WKDownloadDelegate** — standard HTTP downloads (Content-Disposition: attachment, non-displayable MIME)
2. **NativeFetchHandler** (`WKScriptMessageHandlerWithReply`) — universal CORS bypass: overrides `window.fetch()`, cross-origin requests that fail with CORS are retried via Swift URLSession and returned to JS as normal `Response`
3. **DownloadableWebView** (macOS) — replaces context menu "Download Image"/"Download Linked File" with URLSession-based downloads

### Why the fetch override?

Grok downloads images from `imagine-public.x.ai` via JS `fetch()`. WKWebView enforces CORS, so cross-origin fetch fails. Safari handles this at the engine level, but WKWebView exposes the error. Solution: intercept failed cross-origin fetches in JS, delegate to Swift URLSession (no CORS), return data back to JS transparently.

## Build

- Open `Grokk.xcodeproj` in Xcode → ⌘B
- Or: `xcodebuild -scheme Grokk build`
- Bundle ID: `com.iarygin.Grokk.Grokk`
- Requires macOS 14.0+
- Safari Web Inspector: enabled via `isInspectable = true` (Develop → Grokk)

## Conventions

- Keep code minimal and focused, macOS only
- Prefer editing existing files over creating new ones
- Follow existing patterns: singletons, NotificationCenter, UserDefaults
- Do NOT commit proxy credentials (scheme file contains them for local dev only)
- Language: communicate in Russian unless asked otherwise
