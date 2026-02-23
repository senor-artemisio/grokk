# Grokk — Project Instructions

## What is this

macOS/iOS/visionOS wrapper app for [grok.com](https://grok.com) built with Swift 5 + SwiftUI + WebKit. Small codebase (~500 LOC).

## Project Structure

```
Grokk/
  GrokkApp.swift      — App entry point, macOS AppDelegate, tray menu, window management
  ContentView.swift   — WKWebView wrapper, download system, proxy apply logic, delegates
  ProxySettings.swift — ProxySettingsStore (singleton, UserDefaults, @Published), ProxySettingsView (form)
  Grokk.entitlements  — Sandbox: microphone, network client, downloads read-write
  Assets.xcassets/    — App icons (16–1024px), tray icon, accent color
```

## Architecture

- **Pattern**: Singletons + NotificationCenter observers
- **WebViewStore.shared** — manages single WKWebView instance, injects JS, observes proxy changes, handles mic permissions
- **ProxySettingsStore.shared** — proxy config state, persists to UserDefaults, posts `proxySettingsChanged` notifications
- **Platform branching**: `#if os(macOS)` / `#else` for cross-platform support
- **macOS extras**: NSStatusBar tray icon, AppDelegate, right-click context menu, DownloadableWebView subclass

## Key Features

- SOCKS5 proxy support (Network framework, `WKWebViewConfiguration.proxyConfigurations`)
- Microphone permission (AVFoundation + WKUIDelegate)
- Tray icon with menu (Home, Reload, Proxy Settings)
- Persistent WebView data store
- **File downloads** (three mechanisms):
  - `WKNavigationDelegate` + `WKDownloadDelegate` — standard HTTP downloads (Content-Disposition, non-displayable MIME types)
  - `NativeFetchHandler` (`WKScriptMessageHandlerWithReply`) — universal CORS bypass: JS `fetch()` is overridden so cross-origin requests that fail due to CORS are transparently retried via Swift URLSession and returned back to JS
  - `DownloadableWebView` (macOS) — custom context menu replacing "Download Image"/"Download Linked File" with working URLSession-based downloads
- `SaveFileHandler` — JS → Swift message handler to save base64 data to ~/Downloads
- `isInspectable = true` — Safari Web Inspector enabled for debugging (Develop → Grokk)

## Download System Design

WKWebView has a CORS limitation: JS `fetch()` for cross-origin resources fails when the server doesn't send proper CORS headers (e.g. `imagine-public.x.ai`). Safari handles this natively at the engine level, but WKWebView exposes the CORS error to JS.

**Solution**: Override `window.fetch()` via injected JS. Cross-origin fetches first try the original fetch; on CORS failure, the URL is sent to Swift via `WKScriptMessageHandlerWithReply`, downloaded with URLSession (no CORS), and the response is returned to JS as a normal `Response` object. The page code doesn't know the fetch was proxied through Swift.

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
