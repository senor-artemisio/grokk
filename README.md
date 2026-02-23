# Grokk

Native macOS wrapper for [grok.com](https://grok.com) with SOCKS5 proxy support, menu bar integration, and file downloads.

## Features

- **Grok AI in a native window** — lightweight WebView-based client, no browser needed
- **SOCKS5 proxy** — route traffic through a proxy with authentication (useful for regions where Grok is unavailable)
- **File downloads** — download generated images and files directly from the Grok interface (works around WKWebView CORS limitations)
- **Menu bar tray icon** — quick access: left-click to show window, right-click for menu (Home, Reload, Proxy Settings, Quit)
- **Hide from Dock** — run as a tray-only app without a Dock icon
- **Microphone access** — for Grok's voice features
- **Window state persistence** — remembers window size and position

## Requirements

- macOS 14.0+
- Xcode 15+

## Build

```bash
git clone https://github.com/yourusername/grokk.git
cd grokk
open Grokk.xcodeproj
```

Press **⌘B** to build, **⌘R** to run.

## Keyboard Shortcuts

| Action | Shortcut |
|---|---|
| Home | ⌘⇧H |
| Reload | ⌘R |
| Proxy Settings | ⌘, |
| Quit | ⌘Q |

## Proxy Setup

1. Open **Proxy Settings** from the app menu or tray menu (⌘,)
2. Enable **Use Proxy**
3. Enter SOCKS5 proxy address, port, and credentials
4. Click **Save**

## How Downloads Work

Grok generates images on a separate CDN (`imagine-public.x.ai`). In a standard WKWebView, downloading these images fails due to CORS restrictions. Grokk solves this by overriding `fetch()` in JavaScript — when a cross-origin request fails, it transparently retries through Swift's native URLSession (which has no CORS limitations) and returns the result back to JavaScript. The page doesn't know the difference.

Right-click "Download Image" also works via a custom context menu implementation.

## License

GNU v3
