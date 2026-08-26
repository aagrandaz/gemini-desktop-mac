//
//  UserDefaultsKeys.swift
//  GeminiDesktop
//
//  Created by alexcding on 2025-12-13.
//

import Foundation
import AppKit

enum UserDefaultsKeys: String {
    case panelWidth
    case panelHeight
    case pageZoom
    case hideWindowAtLaunch
    case hideDockIcon
    case appTheme
    case userAgentOption
    case customUserAgent
    case panelPosition
    case panelX
    case panelY
    case alwaysOnTop

    // Spark & Modern Settings Keys
    case sidebarMode
    case showInMenuBar
    case openAtLogin
    case sparkRemoteTasksEnabled
    case sparkKeepMacAwake
    case sparkBackupAlertEnabled
    case memoryEnabled
    case voiceSelection
    case speakToWindowReasoning
    case appGoogleWorkspaceEnabled
    case appSearchServicesEnabled
    case appGooglePhotosEnabled
    case appYouTubeEnabled
    case connectedFoldersData
    case debugTelemetryEnabled
}

enum AppTheme: String, CaseIterable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Oscuro"
        }
    }

    func apply() {
        switch self {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    static var current: AppTheme {
        let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.appTheme.rawValue) ?? "system"
        return AppTheme(rawValue: raw) ?? .system
    }
}

enum UserAgentOption: String, CaseIterable {
    case safari
    case chrome
    case firefox
    case custom

    var displayName: String {
        switch self {
        case .safari: return "Safari (Nativo / Passkeys)"
        case .chrome: return "Google Chrome"
        case .firefox: return "Firefox 128"
        case .custom: return "Personalizado"
        }
    }

    static let firefoxUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:128.0) Gecko/20100101 Firefox/128.0"
    static let safariUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"
    static let chromeUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    func userAgentString(custom: String = "") -> String {
        switch self {
        case .firefox: return Self.firefoxUA
        case .safari: return Self.safariUA
        case .chrome: return Self.chromeUA
        case .custom: return custom.isEmpty ? Self.firefoxUA : custom
        }
    }

    func settingsDescription(custom: String = "") -> String {
        switch self {
        case .firefox: return "Identifies as Firefox 128"
        case .safari: return "Identifies as Safari 18.3 on macOS (Supports Touch ID & Passkeys)"
        case .chrome: return "Identifies as Chrome 131 on macOS"
        case .custom: return custom.isEmpty ? "No custom user agent set — falls back to Firefox" : "Using custom user agent string"
        }
    }

    static var current: UserAgentOption {
        let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.userAgentOption.rawValue) ?? "safari"
        return UserAgentOption(rawValue: raw) ?? .safari
    }

    static var currentUserAgentString: String {
        let option = current
        let custom = UserDefaults.standard.string(forKey: UserDefaultsKeys.customUserAgent.rawValue) ?? ""
        return option.userAgentString(custom: custom)
    }
}

enum PanelPosition: String, CaseIterable {
    case bottomLeft
    case bottomCenter
    case bottomRight
    case rememberLast

    var displayName: String {
        switch self {
        case .bottomLeft: return "Parte inferior izquierda"
        case .bottomCenter: return "Parte inferior"
        case .bottomRight: return "Parte inferior derecha"
        case .rememberLast: return "Recordar última posición"
        }
    }

    static var current: PanelPosition {
        let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.panelPosition.rawValue) ?? "bottomCenter"
        return PanelPosition(rawValue: raw) ?? .bottomCenter
    }
}
