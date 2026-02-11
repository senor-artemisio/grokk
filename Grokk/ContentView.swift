//
//  ContentView.swift
//  Grokk
//
//  Created by Артем Ярыгин on 10.02.2026.
//

import SwiftUI
import AVFoundation
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

class WebViewStore {
    static let shared = WebViewStore()
    let webView: WKWebView
    private let permissionDelegate = WebViewPermissionDelegate()

    private init() {
        Self.requestMicrophoneAccessIfNeeded()

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = permissionDelegate
        webView.load(URLRequest(url: URL(string: "https://grok.com")!))
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
