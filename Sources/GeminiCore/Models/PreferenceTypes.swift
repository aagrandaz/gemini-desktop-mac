//
//  PreferenceTypes.swift
//  GeminiCore
//
//  Autor: aagrandaz@gmail.com
//

import Foundation
import AppKit

/// Claves tipadas para el acceso a valores almacenados en `UserDefaults`.
public enum UserDefaultsKeys: String, Sendable {
    /// Ancho del panel flotante de chat.
    case panelWidth
    /// Alto del panel flotante de chat.
    case panelHeight
    /// Nivel de escala o zoom de la página web (1.0 = 100%).
    case pageZoom
    /// Determina si la ventana principal se oculta automáticamente al iniciar la app.
    case hideWindowAtLaunch
    /// Determina si se oculta el ícono de la aplicación en el Dock.
    case hideDockIcon
    /// Tema visual de la aplicación (sistema, claro, oscuro).
    case appTheme
    /// Opción de User Agent seleccionada.
    case userAgentOption
    /// Cadena de User Agent personalizada cuando se elige la opción `.custom`.
    case customUserAgent
    /// Posición en pantalla para la barra de chat emergente.
    case panelPosition
    /// Coordenada X guardada de la última posición del panel flotante.
    case panelX
    /// Coordenada Y guardada de la última posición del panel flotante.
    case panelY
    /// Determina si la ventana principal se mantiene siempre en primer plano.
    case alwaysOnTop

    // Spark & Modern Settings Keys
    /// Modo de presentación de la barra lateral en la interfaz web.
    case sidebarMode
    /// Controla la visualización del ícono en la barra de menú de macOS.
    case showInMenuBar
    /// Determina si la aplicación debe ejecutarse automáticamente al iniciar sesión en macOS.
    case openAtLogin
    /// Habilita la coordinación remota de tareas para agentes Spark.
    case sparkRemoteTasksEnabled
    /// Evita que la Mac entre en modo de reposo mientras se ejecutan tareas prolongadas.
    case sparkKeepMacAwake
    /// Emite alertas cuando no se puede crear un respaldo automático de archivos modificados.
    case sparkBackupAlertEnabled
    /// Habilita la memoria contextual persistente de Gemini.
    case memoryEnabled
    /// Voz sintética seleccionada para las respuestas habladas.
    case voiceSelection
    /// Habilita razonamiento contextual previo a la transcripción en Speak-to-Window.
    case speakToWindowReasoning
    /// Permite integración con Google Workspace (Drive, Docs, Gmail).
    case appGoogleWorkspaceEnabled
    /// Permite integración con los servicios de búsqueda web en tiempo real.
    case appSearchServicesEnabled
    /// Permite integración con Google Fotos.
    case appGooglePhotosEnabled
    /// Permite integración y transcripción de videos de YouTube.
    case appYouTubeEnabled
    /// Datos codificados en JSON de las carpetas locales conectadas.
    case connectedFoldersData
    /// Activa o desactiva la recolección de telemetría e informes de errores.
    case debugTelemetryEnabled
}

/// Opciones de apariencia visual de la aplicación macOS.
public enum AppTheme: String, CaseIterable, Sendable {
    /// Sigue la apariencia configurada a nivel global en el sistema operativo macOS.
    case system
    /// Fuerza el tema claro (Aqua).
    case light
    /// Fuerza el tema oscuro (Dark Aqua).
    case dark

    /// Nombre legible en español para desplegar en selectores de la interfaz de usuario.
    public var displayName: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Oscuro"
        }
    }

    /// Aplica la apariencia correspondiente a la instancia compartida de `NSApplication`.
    @MainActor
    public func apply() {
        switch self {
        case .system:
            NSApp?.appearance = nil
        case .light:
            NSApp?.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp?.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

/// Identidades de navegador (User-Agent) soportadas para la navegación dentro de WKWebView.
public enum UserAgentOption: String, CaseIterable, Sendable {
    /// Identifica la sesión como Safari nativo en macOS (requerido para compatibilidad con Passkeys y Google Auth).
    case safari
    /// Identifica la sesión como Google Chrome.
    case chrome
    /// Identifica la sesión como Mozilla Firefox.
    case firefox
    /// Permite especificar una cadena User-Agent personalizada definida por el usuario.
    case custom

    /// Nombre visible en la configuración.
    public var displayName: String {
        switch self {
        case .safari: return "Safari (Nativo / Passkeys)"
        case .chrome: return "Google Chrome"
        case .firefox: return "Firefox 128"
        case .custom: return "Personalizado"
        }
    }

    /// Cadena User-Agent predeterminada simulando Firefox 128 en macOS.
    public static let firefoxUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:128.0) Gecko/20100101 Firefox/128.0"
    /// Cadena User-Agent predeterminada simulando Safari 18.3 en macOS.
    public static let safariUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"
    /// Cadena User-Agent predeterminada simulando Chrome 131 en macOS.
    public static let chromeUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    /// Resuelve la cadena final de User-Agent basada en la opción activa.
    /// - Parameter custom: Cadena personalizada provista por el usuario.
    /// - Returns: Cadena User-Agent válida.
    public func userAgentString(custom: String = "") -> String {
        switch self {
        case .firefox: return Self.firefoxUA
        case .safari: return Self.safariUA
        case .chrome: return Self.chromeUA
        case .custom: return custom.isEmpty ? Self.firefoxUA : custom
        }
    }

    /// Retorna una descripción explicativa para la vista de ajustes.
    /// - Parameter custom: Cadena personalizada actual.
    /// - Returns: Texto descriptivo de la selección.
    public func settingsDescription(custom: String = "") -> String {
        switch self {
        case .firefox: return "Identifies as Firefox 128"
        case .safari: return "Identifies as Safari 18.3 on macOS (Supports Touch ID & Passkeys)"
        case .chrome: return "Identifies as Chrome 131 on macOS"
        case .custom: return custom.isEmpty ? "No custom user agent set — falls back to Firefox" : "Using custom user agent string"
        }
    }
}

/// Opciones de anclaje y ubicación en pantalla para el panel emergente de chat.
public enum PanelPosition: String, CaseIterable, Sendable {
    /// Esquina inferior izquierda sobre la barra de tareas/dock.
    case bottomLeft
    /// Centro inferior de la pantalla sobre la barra de tareas/dock.
    case bottomCenter
    /// Esquina inferior derecha de la pantalla sobre la barra de tareas/dock.
    case bottomRight
    /// Conserva y restaura las últimas coordenadas personalizadas donde el usuario arrastró la ventana.
    case rememberLast

    /// Nombre visible en el selector de ajustes.
    public var displayName: String {
        switch self {
        case .bottomLeft: return "Parte inferior izquierda"
        case .bottomCenter: return "Parte inferior"
        case .bottomRight: return "Parte inferior derecha"
        case .rememberLast: return "Recordar última posición"
        }
    }
}

/// Secciones o pestañas disponibles en la ventana de Ajustes de la aplicación.
public enum SettingsCategory: String, CaseIterable, Identifiable, Sendable {
    /// Ajustes visuales, zoom y opciones de integración con el sistema.
    case appearance = "Apariencia"
    /// Configuración de atajos de teclado globales y locales.
    case shortcuts = "Accesos directos"
    /// Ajustes de instrucciones y memoria contextual de Gemini.
    case customIntelligence = "Inteligencia personalizada"
    /// Conexiones con extensiones de Google Workspace, Drive, etc.
    case connectedApps = "Apps conectadas"
    /// Selección de la voz sintética de Gemini.
    case geminiVoice = "Voz de Gemini"
    /// Configuración de la funcionalidad de dictado interactivo Speak-to-Window.
    case speakToWindow = "Speak to Window"
    /// Ajustes avanzados y automatizaciones del motor Gemini Spark.
    case geminiSpark = "Gemini Spark"
    /// Indicadores de cuotas y consumo de tokens o llamadas API.
    case usageLimits = "Límites de uso"
    /// Información sobre la versión, créditos y licencia de la aplicación.
    case about = "Acerca de la app"
    /// Opciones avanzadas para desarrolladores, restablecimiento de cookies y telemetría.
    case debug = "Depuración"

    /// Identificador único para compatibilidad con colecciones SwiftUI.
    public var id: String { rawValue }

    /// Nombre del símbolo SF Symbol asociado a la categoría.
    public var icon: String {
        switch self {
        case .appearance: return "paintbrush"
        case .shortcuts: return "command"
        case .customIntelligence: return "brain"
        case .connectedApps: return "square.stack.3d.up"
        case .geminiVoice: return "waveform"
        case .speakToWindow: return "mic.and.signal.meter"
        case .geminiSpark: return "sparkles"
        case .usageLimits: return "chart.bar"
        case .about: return "info.circle"
        case .debug: return "ladybug"
        }
    }
}
