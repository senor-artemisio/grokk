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

final class WebViewPermissionDelegate: NSObject, WKUIDelegate {
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
}

@MainActor
class WebViewStore {
    static let shared = WebViewStore()
    let webView: WKWebView
    private let permissionDelegate = WebViewPermissionDelegate()
    private var proxySettingsObserver: NSObjectProtocol?

    private init() {
        Self.requestMicrophoneAccessIfNeeded()

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = permissionDelegate

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
