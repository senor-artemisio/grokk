//
//  ContentView.swift
//  Grokk
//
//  Created by Артем Ярыгин on 10.02.2026.
//

import SwiftUI
import AVFoundation
import Network
import WebKit
#if os(macOS)
import AppKit
#endif

// MARK: - Native fetch handler (JS sends URL → Swift downloads via URLSession → returns data to JS)

final class NativeFetchHandler: NSObject, WKScriptMessageHandlerWithReply {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping (Any?, String?) -> Void
    ) {
        guard let dict = message.body as? [String: Any],
              let urlString = dict["url"] as? String,
              let url = URL(string: urlString)
        else {
            replyHandler(nil, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        if let method = dict["method"] as? String {
            request.httpMethod = method
        }
        if let headers = dict["headers"] as? [String: String] {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                replyHandler(nil, error.localizedDescription)
                return
            }
            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                replyHandler(nil, "No data")
                return
            }

            let base64 = data.base64EncodedString()
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "application/octet-stream"
            let contentDisposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition") ?? ""

            let result: [String: Any] = [
                "status": httpResponse.statusCode,
                "contentType": contentType,
                "contentDisposition": contentDisposition,
                "data": base64
            ]
            replyHandler(result, nil)
        }.resume()
    }
}

// MARK: - Save-to-downloads handler (JS sends base64 data → Swift saves file)

final class SaveFileHandler: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: String],
              let base64 = dict["data"],
              let filename = dict["filename"],
              let data = Data(base64Encoded: base64)
        else { return }
        Self.saveToDownloads(data: data, filename: filename)
    }

    static func saveToDownloads(data: Data, filename: String) {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        var destinationURL = downloadsURL.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            let name = destinationURL.deletingPathExtension().lastPathComponent
            let ext = destinationURL.pathExtension
            var counter = 1
            repeat {
                let newName = ext.isEmpty ? "\(name) (\(counter))" : "\(name) (\(counter)).\(ext)"
                destinationURL = downloadsURL.appendingPathComponent(newName)
                counter += 1
            } while FileManager.default.fileExists(atPath: destinationURL.path)
        }

        do {
            try data.write(to: destinationURL)
            #if os(macOS)
            NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
            #endif
        } catch {
            print("[Grokk] Failed to save file: \(error.localizedDescription)")
        }
    }
}

// MARK: - WebView delegate

final class WebViewDelegate: NSObject, WKUIDelegate, WKNavigationDelegate, WKDownloadDelegate {

    // MARK: WKUIDelegate — media permissions

    @available(iOS 15.0, macOS 12.0, *)
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        switch type {
        case .microphone, .cameraAndMicrophone:
            decisionHandler(.grant)
        default:
            decisionHandler(.deny)
        }
    }

    // MARK: WKNavigationDelegate — intercept downloads

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
            return
        }

        if let response = navigationResponse.response as? HTTPURLResponse,
           let contentDisposition = response.value(forHTTPHeaderField: "Content-Disposition"),
           contentDisposition.lowercased().contains("attachment") {
            decisionHandler(.download)
            return
        }

        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download, preferences)
            return
        }
        decisionHandler(.allow, preferences)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    // MARK: WKDownloadDelegate

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        var destinationURL = downloadsURL.appendingPathComponent(suggestedFilename)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            let name = destinationURL.deletingPathExtension().lastPathComponent
            let ext = destinationURL.pathExtension
            var counter = 1
            repeat {
                let newName = ext.isEmpty ? "\(name) (\(counter))" : "\(name) (\(counter)).\(ext)"
                destinationURL = downloadsURL.appendingPathComponent(newName)
                counter += 1
            } while FileManager.default.fileExists(atPath: destinationURL.path)
        }

        completionHandler(destinationURL)
    }

    func downloadDidFinish(_ download: WKDownload) {}

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        print("[Grokk] Download failed: \(error.localizedDescription)")
    }
}

// MARK: - macOS: WKWebView subclass with custom context menu

#if os(macOS)
class DownloadableWebView: WKWebView {

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        for (index, item) in menu.items.enumerated().reversed() {
            let id = item.identifier?.rawValue ?? ""
            if id == "WKMenuItemIdentifierDownloadImage" {
                let replacement = NSMenuItem(title: item.title, action: #selector(handleDownloadImage), keyEquivalent: "")
                replacement.target = self
                menu.removeItem(at: index)
                menu.insertItem(replacement, at: index)
            } else if id == "WKMenuItemIdentifierDownloadLinkedFile" {
                let replacement = NSMenuItem(title: item.title, action: #selector(handleDownloadLinkedFile), keyEquivalent: "")
                replacement.target = self
                menu.removeItem(at: index)
                menu.insertItem(replacement, at: index)
            }
        }
        super.willOpenMenu(menu, with: event)
    }

    @objc private func handleDownloadImage() {
        evaluateJavaScript("window._grokk_contextImageURL") { [weak self] result, _ in
            guard let urlString = result as? String, !urlString.isEmpty else { return }
            self?.downloadResource(from: urlString, fallbackExtension: "png")
        }
    }

    @objc private func handleDownloadLinkedFile() {
        evaluateJavaScript("window._grokk_contextLinkURL") { [weak self] result, _ in
            guard let urlString = result as? String, !urlString.isEmpty else { return }
            self?.downloadResource(from: urlString, fallbackExtension: nil)
        }
    }

    private func downloadResource(from urlString: String, fallbackExtension: String?) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            var filename = response?.suggestedFilename ?? url.lastPathComponent
            if filename.isEmpty || filename == "/" {
                filename = "download.\(fallbackExtension ?? "bin")"
            }
            DispatchQueue.main.async {
                SaveFileHandler.saveToDownloads(data: data, filename: filename)
            }
        }.resume()
    }
}
#endif

// MARK: - WebViewStore

@MainActor
class WebViewStore {
    static let shared = WebViewStore()
    let webView: WKWebView
    private let webViewDelegate = WebViewDelegate()
    private let nativeFetchHandler = NativeFetchHandler()
    private let saveFileHandler = SaveFileHandler()
    private var proxySettingsObserver: NSObjectProtocol?

    private init() {
        Self.requestMicrophoneAccessIfNeeded()

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        // JS → Swift message handlers
        config.userContentController.addScriptMessageHandler(nativeFetchHandler, contentWorld: .page, name: "nativeFetch")
        config.userContentController.add(saveFileHandler, name: "saveFile")

        // Inject JS: override fetch() to fall back to native Swift on CORS errors
        let script = WKUserScript(source: Self.fetchOverrideJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)

        #if os(macOS)
        webView = DownloadableWebView(frame: .zero, configuration: config)
        #else
        webView = WKWebView(frame: .zero, configuration: config)
        #endif
        webView.uiDelegate = webViewDelegate
        webView.navigationDelegate = webViewDelegate
        if #available(macOS 13.3, iOS 16.4, *) {
            webView.isInspectable = true
        }

        applyProxySettings(ProxySettingsStore.shared.currentSettings, reloadAfterApply: false)
        proxySettingsObserver = NotificationCenter.default.addObserver(
            forName: .proxySettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let settings = notification.object as? ProxySettings else { return }
            Task { @MainActor [weak self] in
                self?.applyProxySettings(settings, reloadAfterApply: true)
            }
        }

        webView.load(URLRequest(url: URL(string: "https://grok.com")!))
    }

    deinit {
        if let proxySettingsObserver {
            NotificationCenter.default.removeObserver(proxySettingsObserver)
        }
    }

    // Universal fetch() override:
    // 1. Try original fetch
    // 2. On CORS/network error for cross-origin requests → retry via Swift URLSession
    // 3. Return response to JS transparently
    private static let fetchOverrideJS = """
    (function() {
        // --- Context menu tracking for right-click downloads ---
        document.addEventListener('contextmenu', function(e) {
            var el = e.target;
            window._grokk_contextImageURL = null;
            window._grokk_contextLinkURL = null;

            if (el.tagName === 'IMG' && el.src) {
                window._grokk_contextImageURL = el.src;
            } else {
                var pic = el.closest('picture');
                if (pic) {
                    var img = pic.querySelector('img');
                    if (img && img.src) window._grokk_contextImageURL = img.src;
                }
                if (!window._grokk_contextImageURL) {
                    var bg = window.getComputedStyle(el).backgroundImage;
                    if (bg && bg !== 'none') {
                        window._grokk_contextImageURL = bg.replace(/^url\\(['"]?/, '').replace(/['"]?\\)$/, '');
                    }
                }
            }
            var link = el.closest('a');
            if (link && link.href) window._grokk_contextLinkURL = link.href;
        }, true);

        // --- Universal fetch() override with CORS fallback to native Swift ---
        var _origFetch = window.fetch;
        window.fetch = function(input, init) {
            var url = (typeof input === 'string') ? input : (input && input.url ? input.url : '');
            var isCrossOrigin = false;
            try {
                isCrossOrigin = url && new URL(url, location.href).origin !== location.origin;
            } catch(e) {}

            if (!isCrossOrigin) {
                return _origFetch.apply(window, arguments);
            }

            // Cross-origin: try original fetch first, fall back to native on failure
            return _origFetch.apply(window, arguments).catch(function(err) {
                console.log('[Grokk] fetch CORS failed for ' + url + ', retrying via native Swift');

                var method = (init && init.method) ? init.method : 'GET';
                var headers = {};
                if (init && init.headers) {
                    if (init.headers instanceof Headers) {
                        init.headers.forEach(function(v, k) { headers[k] = v; });
                    } else if (typeof init.headers === 'object') {
                        headers = init.headers;
                    }
                }

                return window.webkit.messageHandlers.nativeFetch.postMessage({
                    url: url,
                    method: method,
                    headers: headers
                }).then(function(result) {
                    if (!result) throw new Error('Native fetch returned null');
                    var bytes = Uint8Array.from(atob(result.data), function(c) { return c.charCodeAt(0); });
                    var blob = new Blob([bytes], { type: result.contentType });
                    var response = new Response(blob, {
                        status: result.status,
                        headers: {
                            'Content-Type': result.contentType,
                            'Content-Disposition': result.contentDisposition || ''
                        }
                    });
                    return response;
                });
            });
        };

        console.log('[Grokk] native fetch fallback loaded');
    })();
    """

    private func applyProxySettings(_ settings: ProxySettings, reloadAfterApply: Bool) {
        guard #available(macOS 14.0, iOS 17.0, *) else { return }

        let dataStore = webView.configuration.websiteDataStore
        guard settings.useProxy else {
            dataStore.proxyConfigurations = []
            if reloadAfterApply {
                reloadWebView()
            }
            return
        }

        let urlText = settings.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlText.isEmpty else {
            dataStore.proxyConfigurations = []
            if reloadAfterApply {
                reloadWebView()
            }
            return
        }

        let components = URLComponents(string: urlText)
        let host = (components?.host ?? urlText).trimmingCharacters(in: .whitespacesAndNewlines)
        let manualPortText = settings.port.trimmingCharacters(in: .whitespacesAndNewlines)
        let portText = manualPortText.isEmpty ? (components?.port.map(String.init) ?? "") : manualPortText
        guard
            !host.isEmpty,
            let portValue = UInt16(portText),
            let port = NWEndpoint.Port(rawValue: portValue)
        else {
            dataStore.proxyConfigurations = []
            if reloadAfterApply {
                reloadWebView()
            }
            return
        }

        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: port)
        let proxyConfiguration = ProxyConfiguration(socksv5Proxy: endpoint)

        let login = settings.login.trimmingCharacters(in: .whitespacesAndNewlines)
        if !login.isEmpty {
            proxyConfiguration.applyCredential(username: login, password: settings.password)
        }

        dataStore.proxyConfigurations = [proxyConfiguration]
        if reloadAfterApply {
            reloadWebView()
        }
    }

    private func reloadWebView() {
        if webView.url == nil {
            webView.load(URLRequest(url: URL(string: "https://grok.com")!))
            return
        }
        webView.reload()
    }

    private static func requestMicrophoneAccessIfNeeded() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else { return }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
}

// MARK: - SwiftUI WebView wrapper

#if os(macOS)
struct WebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        WebViewStore.shared.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#else
struct WebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        WebViewStore.shared.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#endif

struct ContentView: View {
    var body: some View {
        WebView()
    }
}
