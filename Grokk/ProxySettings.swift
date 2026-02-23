//
//  ProxySettings.swift
//  Grokk
//
//  Created by Codex on 13.02.2026.
//

import Foundation
import Combine
import SwiftUI

extension Notification.Name {
    static let proxySettingsDidChange = Notification.Name("proxySettingsDidChange")
}

struct ProxySettings: Sendable {
    var url: String
    var port: String
    var login: String
    var password: String
    var useProxy: Bool
}

@MainActor
final class ProxySettingsStore: ObservableObject {
    static let shared = ProxySettingsStore()

    private enum Keys {
        static let url = "proxy.url"
        static let port = "proxy.port"
        static let login = "proxy.login"
        static let password = "proxy.password"
        static let useProxy = "proxy.useProxy"
    }

    @Published var url: String = ""
    @Published var port: String = ""
    @Published var login: String = ""
    @Published var password: String = ""
    @Published var useProxy: Bool = false

    var currentSettings: ProxySettings {
        ProxySettings(url: url, port: port, login: login, password: password, useProxy: useProxy)
    }

    private let defaults = UserDefaults.standard

    private init() {
        url = defaults.string(forKey: Keys.url) ?? ""
        port = defaults.string(forKey: Keys.port) ?? ""
        login = defaults.string(forKey: Keys.login) ?? ""
        password = defaults.string(forKey: Keys.password) ?? ""
        useProxy = defaults.bool(forKey: Keys.useProxy)
    }

    func save(_ settings: ProxySettings) {
        url = settings.url
        port = settings.port
        login = settings.login
        password = settings.password
        useProxy = settings.useProxy

        defaults.set(url, forKey: Keys.url)
        defaults.set(port, forKey: Keys.port)
        defaults.set(login, forKey: Keys.login)
        defaults.set(password, forKey: Keys.password)
        defaults.set(useProxy, forKey: Keys.useProxy)

        NotificationCenter.default.post(name: .proxySettingsDidChange, object: settings)
    }
}

struct ProxySettingsView: View {
    private let settings = ProxySettingsStore.shared
    @State private var url: String
    @State private var port: String
    @State private var login: String
    @State private var password: String
    @State private var useProxy: Bool

    init() {
        let current = ProxySettingsStore.shared.currentSettings
        _url = State(initialValue: current.url)
        _port = State(initialValue: current.port)
        _login = State(initialValue: current.login)
        _password = State(initialValue: current.password)
        _useProxy = State(initialValue: current.useProxy)
    }

    var body: some View {
        Form {
            Toggle("Use Proxy", isOn: $useProxy)
            TextField("URL", text: $url)
            TextField("Port", text: $port)
            TextField("Login", text: $login)
            SecureField("Password", text: $password)

            HStack {
                Spacer()
                Button("Сохранить") {
                    settings.save(
                        ProxySettings(
                            url: url,
                            port: port,
                            login: login,
                            password: password,
                            useProxy: useProxy
                        )
                    )
                    #if os(macOS)
                    NSApp.keyWindow?.close()
                    #endif
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(minWidth: 380)
    }
}
