//
//  PreferencesRepository.swift
//  GeminiCore
//
//  Autor: aagrandaz@gmail.com
//

import Foundation
import Observation

/// Repositorio centralizado para la persistencia reactiva en `UserDefaults`.
/// Implementa el patrón Repository actuando como Single Source of Truth para todas las opciones de la aplicación.
@Observable
@MainActor
public final class PreferencesRepository: PreferencesStoring {
    /// Instancia subyacente de `UserDefaults` empleada para lectura y escritura.
    private let defaults: UserDefaults

    /// Ancho del panel de chat flotante guardado en disco.
    public var panelWidth: Double {
        didSet { defaults.set(panelWidth, forKey: UserDefaultsKeys.panelWidth.rawValue) }
    }

    /// Alto del panel de chat flotante guardado en disco.
    public var panelHeight: Double {
        didSet { defaults.set(panelHeight, forKey: UserDefaultsKeys.panelHeight.rawValue) }
    }

    /// Coordenada horizontal X persistida para recordar la posición del panel.
    public var panelX: Double? {
        didSet {
            if let panelX {
                defaults.set(panelX, forKey: UserDefaultsKeys.panelX.rawValue)
            } else {
                defaults.removeObject(forKey: UserDefaultsKeys.panelX.rawValue)
            }
        }
    }

    /// Coordenada vertical Y persistida para recordar la posición del panel.
    public var panelY: Double? {
        didSet {
            if let panelY {
                defaults.set(panelY, forKey: UserDefaultsKeys.panelY.rawValue)
            } else {
                defaults.removeObject(forKey: UserDefaultsKeys.panelY.rawValue)
            }
        }
    }

    /// Posición del panel seleccionada por el usuario.
    public var panelPosition: PanelPosition {
        didSet { defaults.set(panelPosition.rawValue, forKey: UserDefaultsKeys.panelPosition.rawValue) }
    }

    /// Factor de escala visual aplicado a la vista web.
    public var pageZoom: Double {
        didSet { defaults.set(pageZoom, forKey: UserDefaultsKeys.pageZoom.rawValue) }
    }

    /// Determina si la ventana principal permanece oculta tras arrancar la aplicación.
    public var hideWindowAtLaunch: Bool {
        didSet { defaults.set(hideWindowAtLaunch, forKey: UserDefaultsKeys.hideWindowAtLaunch.rawValue) }
    }

    /// Oculta o muestra el ícono de la aplicación en el Dock de macOS.
    public var hideDockIcon: Bool {
        didSet { defaults.set(hideDockIcon, forKey: UserDefaultsKeys.hideDockIcon.rawValue) }
    }

    /// Determina si la ventana principal se configura como ventana flotante siempre visible.
    public var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: UserDefaultsKeys.alwaysOnTop.rawValue) }
    }

    /// Tema de apariencia visual activo.
    public var appTheme: AppTheme {
        didSet { defaults.set(appTheme.rawValue, forKey: UserDefaultsKeys.appTheme.rawValue) }
    }

    /// Identidad de User-Agent seleccionada.
    public var userAgentOption: UserAgentOption {
        didSet { defaults.set(userAgentOption.rawValue, forKey: UserDefaultsKeys.userAgentOption.rawValue) }
    }

    /// Cadena User-Agent manual provista por el usuario.
    public var customUserAgent: String {
        didSet { defaults.set(customUserAgent, forKey: UserDefaultsKeys.customUserAgent.rawValue) }
    }

    /// Cadena final calculada del User-Agent.
    public var currentUserAgentString: String {
        userAgentOption.userAgentString(custom: customUserAgent)
    }

    /// Indica si se debe mostrar el menú en la barra de estado de macOS.
    public var showInMenuBar: Bool {
        didSet { defaults.set(showInMenuBar, forKey: UserDefaultsKeys.showInMenuBar.rawValue) }
    }

    /// Indica si la app debe abrirse al encender/iniciar sesión en la Mac.
    public var openAtLogin: Bool {
        didSet { defaults.set(openAtLogin, forKey: UserDefaultsKeys.openAtLogin.rawValue) }
    }

    /// Controla la ejecución remota de tareas Spark.
    public var sparkRemoteTasksEnabled: Bool {
        didSet { defaults.set(sparkRemoteTasksEnabled, forKey: UserDefaultsKeys.sparkRemoteTasksEnabled.rawValue) }
    }

    /// Impide que el equipo entre en reposo mientras Spark trabaja.
    public var sparkKeepMacAwake: Bool {
        didSet { defaults.set(sparkKeepMacAwake, forKey: UserDefaultsKeys.sparkKeepMacAwake.rawValue) }
    }

    /// Muestra alertas previas cuando no se puede crear respaldo de un archivo modificado.
    public var sparkBackupAlertEnabled: Bool {
        didSet { defaults.set(sparkBackupAlertEnabled, forKey: UserDefaultsKeys.sparkBackupAlertEnabled.rawValue) }
    }

    /// Activa o desactiva la memoria contextual de Gemini.
    public var memoryEnabled: Bool {
        didSet { defaults.set(memoryEnabled, forKey: UserDefaultsKeys.memoryEnabled.rawValue) }
    }

    /// Activa el análisis previo en el modo Speak to Window.
    public var speakToWindowReasoning: Bool {
        didSet { defaults.set(speakToWindowReasoning, forKey: UserDefaultsKeys.speakToWindowReasoning.rawValue) }
    }

    /// Nombre de la voz seleccionada para respuestas de audio.
    public var voiceSelection: String {
        didSet { defaults.set(voiceSelection, forKey: UserDefaultsKeys.voiceSelection.rawValue) }
    }

    /// Conexión con Google Workspace habilitada.
    public var appGoogleWorkspaceEnabled: Bool {
        didSet { defaults.set(appGoogleWorkspaceEnabled, forKey: UserDefaultsKeys.appGoogleWorkspaceEnabled.rawValue) }
    }

    /// Conexión con Búsqueda de Google habilitada.
    public var appSearchServicesEnabled: Bool {
        didSet { defaults.set(appSearchServicesEnabled, forKey: UserDefaultsKeys.appSearchServicesEnabled.rawValue) }
    }

    /// Conexión con Google Fotos habilitada.
    public var appGooglePhotosEnabled: Bool {
        didSet { defaults.set(appGooglePhotosEnabled, forKey: UserDefaultsKeys.appGooglePhotosEnabled.rawValue) }
    }

    /// Conexión con YouTube habilitada.
    public var appYouTubeEnabled: Bool {
        didSet { defaults.set(appYouTubeEnabled, forKey: UserDefaultsKeys.appYouTubeEnabled.rawValue) }
    }

    /// Telemetría y diagnóstico habilitados.
    public var debugTelemetryEnabled: Bool {
        didSet { defaults.set(debugTelemetryEnabled, forKey: UserDefaultsKeys.debugTelemetryEnabled.rawValue) }
    }

    /// Lista de carpetas locales conectadas, serializadas y almacenadas como Data JSON.
    public var connectedFolders: [ConnectedFolder] {
        didSet {
            if let encoded = try? JSONEncoder().encode(connectedFolders) {
                defaults.set(encoded, forKey: UserDefaultsKeys.connectedFoldersData.rawValue)
            }
        }
    }

    /// Inicializa el repositorio cargando los valores persistidos o estableciendo valores por omisión.
    /// - Parameter defaults: Instancia de `UserDefaults` a utilizar (por defecto `.standard`).
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.panelWidth = defaults.double(forKey: UserDefaultsKeys.panelWidth.rawValue)
        self.panelHeight = defaults.double(forKey: UserDefaultsKeys.panelHeight.rawValue)

        if defaults.object(forKey: UserDefaultsKeys.panelX.rawValue) != nil {
            self.panelX = defaults.double(forKey: UserDefaultsKeys.panelX.rawValue)
        } else {
            self.panelX = nil
        }

        if defaults.object(forKey: UserDefaultsKeys.panelY.rawValue) != nil {
            self.panelY = defaults.double(forKey: UserDefaultsKeys.panelY.rawValue)
        } else {
            self.panelY = nil
        }

        let posRaw = defaults.string(forKey: UserDefaultsKeys.panelPosition.rawValue) ?? PanelPosition.bottomCenter.rawValue
        self.panelPosition = PanelPosition(rawValue: posRaw) ?? .bottomCenter

        let savedZoom = defaults.double(forKey: UserDefaultsKeys.pageZoom.rawValue)
        self.pageZoom = savedZoom > 0 ? savedZoom : 1.0

        self.hideWindowAtLaunch = defaults.bool(forKey: UserDefaultsKeys.hideWindowAtLaunch.rawValue)
        self.hideDockIcon = defaults.bool(forKey: UserDefaultsKeys.hideDockIcon.rawValue)
        self.alwaysOnTop = defaults.bool(forKey: UserDefaultsKeys.alwaysOnTop.rawValue)

        let themeRaw = defaults.string(forKey: UserDefaultsKeys.appTheme.rawValue) ?? AppTheme.system.rawValue
        self.appTheme = AppTheme(rawValue: themeRaw) ?? .system

        let uaRaw = defaults.string(forKey: UserDefaultsKeys.userAgentOption.rawValue) ?? UserAgentOption.safari.rawValue
        self.userAgentOption = UserAgentOption(rawValue: uaRaw) ?? .safari
        self.customUserAgent = defaults.string(forKey: UserDefaultsKeys.customUserAgent.rawValue) ?? ""

        self.showInMenuBar = defaults.object(forKey: UserDefaultsKeys.showInMenuBar.rawValue) as? Bool ?? true
        self.openAtLogin = defaults.bool(forKey: UserDefaultsKeys.openAtLogin.rawValue)
        self.sparkRemoteTasksEnabled = defaults.object(forKey: UserDefaultsKeys.sparkRemoteTasksEnabled.rawValue) as? Bool ?? true
        self.sparkKeepMacAwake = defaults.object(forKey: UserDefaultsKeys.sparkKeepMacAwake.rawValue) as? Bool ?? true
        self.sparkBackupAlertEnabled = defaults.object(forKey: UserDefaultsKeys.sparkBackupAlertEnabled.rawValue) as? Bool ?? true
        self.memoryEnabled = defaults.object(forKey: UserDefaultsKeys.memoryEnabled.rawValue) as? Bool ?? true
        self.speakToWindowReasoning = defaults.object(forKey: UserDefaultsKeys.speakToWindowReasoning.rawValue) as? Bool ?? true
        self.voiceSelection = defaults.string(forKey: UserDefaultsKeys.voiceSelection.rawValue) ?? "Orbit"

        self.appGoogleWorkspaceEnabled = defaults.object(forKey: UserDefaultsKeys.appGoogleWorkspaceEnabled.rawValue) as? Bool ?? true
        self.appSearchServicesEnabled = defaults.object(forKey: UserDefaultsKeys.appSearchServicesEnabled.rawValue) as? Bool ?? true
        self.appGooglePhotosEnabled = defaults.object(forKey: UserDefaultsKeys.appGooglePhotosEnabled.rawValue) as? Bool ?? true
        self.appYouTubeEnabled = defaults.object(forKey: UserDefaultsKeys.appYouTubeEnabled.rawValue) as? Bool ?? true
        self.debugTelemetryEnabled = defaults.object(forKey: UserDefaultsKeys.debugTelemetryEnabled.rawValue) as? Bool ?? true

        if let data = defaults.data(forKey: UserDefaultsKeys.connectedFoldersData.rawValue),
           let decoded = try? JSONDecoder().decode([ConnectedFolder].self, from: data) {
            self.connectedFolders = decoded
        } else {
            self.connectedFolders = []
        }
    }
}
