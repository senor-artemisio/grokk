# Grokk — Project Instructions

## What is this

macOS/iOS/visionOS wrapper app for [grok.com](https://grok.com) built with Swift 5 + SwiftUI + WebKit. Small codebase (~400 LOC).

## Project Structure

```
Grokk/
  GrokkApp.swift      — App entry point, macOS AppDelegate, tray menu, window management
  ContentView.swift   — WKWebView wrapper (NSViewRepresentable/UIViewRepresentable), proxy apply logic
  ProxySettings.swift — ProxySettingsStore (singleton, UserDefaults, @Published), ProxySettingsView (form)
  Grokk.entitlements  — Sandbox: microphone, network client
  Assets.xcassets/    — App icons (16–1024px), tray icon, accent color
```

## Architecture

- **Pattern**: Singletons + NotificationCenter observers
- **WebViewStore.shared** — manages single WKWebView instance, observes proxy changes, handles mic permissions
- **ProxySettingsStore.shared** — proxy config state, persists to UserDefaults, posts `proxySettingsChanged` notifications
- **Platform branching**: `#if os(macOS)` / `#else` for cross-platform support
- **macOS extras**: NSStatusBar tray icon, AppDelegate, right-click context menu

## Key Features

- SOCKS5 proxy support (Network framework, `WKWebViewConfiguration.proxyConfigurations`)
- Microphone permission (AVFoundation + WKUIDelegate)
- Tray icon with menu (Home, Reload, Proxy Settings)
- Persistent WebView data store

## Build

- Open `Grokk.xcodeproj` in Xcode and build (Cmd+B)
- Or: `xcodebuild -scheme Grokk -configuration Release build`
- Bundle ID: `com.iarygin.Grokk.Grokk`
- Team: `946Z5K2VLH`
- Min targets: macOS 26.2, iOS 26.2, visionOS 26.2

## Conventions

- Use SwiftUI idioms, keep code minimal and focused
- Prefer editing existing files over creating new ones
- Follow existing singleton + NotificationCenter pattern for new stores
- Use `#if os(macOS)` for platform-specific code
- Do NOT commit proxy credentials (scheme file contains them for local dev only)
- Language: communicate in Russian unless asked otherwise
