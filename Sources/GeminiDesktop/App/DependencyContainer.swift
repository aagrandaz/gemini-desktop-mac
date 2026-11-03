//
//  DependencyContainer.swift
//  GeminiDesktop
//
//  Autor: aagrandaz@gmail.com
//

import Foundation
import GeminiCore
import GeminiWebBridge
import GeminiAppKit
import GeminiUI

/// Contenedor de Inyección de Dependencias (Composition Root / AppEnvironment).
/// Conecta todas las capas de la arquitectura modular mediante Inversión de Control (IoC) y pasaje explícito por constructor.
@MainActor
public final class DependencyContainer {
    /// Indica si la sesión está operando en modo de desarrollo aislado sin interferir con la app de producción.
    public let isIsolatedDevMode: Bool
    /// Repositorio reactivo de configuración del usuario.
    public let preferences: PreferencesRepository
    /// Bus de eventos de la aplicación para comunicación desacoplada.
    public let eventBus: AppEventBus
    /// Gestor de carpetas conectadas del sistema de archivos.
    public let folderManager: FolderManaging
    /// Gestor de atajos de teclado globales.
    public let hotkeyManager: HotkeyManaging
    /// Puente de automatización web y sincronización con el DOM.
    public let webBridge: GeminiWebBridging
    /// Modelo de estado del WebView y navegación.
    public let webViewModel: WebViewModel
    /// Gestor de presentación y dimensiones de ventanas AppKit.
    public let windowManager: WindowManaging
    /// Coordinador central del flujo de la interfaz de usuario.
    public let coordinator: AppCoordinator

    /// Inicializador flexible con soporte de sobreescritura de dependencias (útil para pruebas unitarias).
    /// - Parameters:
    ///   - isIsolatedDevMode: Bandera explícita para activar modo desarrollo aislado (o auto-detectada si es nil).
    ///   - preferences: Repositorio de configuración opcional.
    ///   - eventBus: Bus de eventos opcional.
    ///   - folderManager: Gestor de carpetas opcional.
    ///   - hotkeyManager: Administrador de atajos opcional.
    ///   - webBridge: Puente web opcional.
    ///   - webViewModel: Modelo de vista web opcional.
    ///   - windowManager: Gestor de ventanas opcional.
    public init(
        isIsolatedDevMode: Bool? = nil,
        preferences: PreferencesRepository? = nil,
        eventBus: AppEventBus? = nil,
        folderManager: FolderManaging? = nil,
        hotkeyManager: HotkeyManaging? = nil,
        webBridge: GeminiWebBridging? = nil,
        webViewModel: WebViewModel? = nil,
        windowManager: WindowManaging? = nil
    ) {
        let detectedDevMode = isIsolatedDevMode ?? Self.detectIsolatedDevEnvironment()
        self.isIsolatedDevMode = detectedDevMode

        let defaultSuite: UserDefaults = detectedDevMode
            ? (UserDefaults(suiteName: "com.alexcding.geminidesktop.dev.arm64") ?? .standard)
            : .standard

        let resolvedPreferences = preferences ?? PreferencesRepository(defaults: defaultSuite)
        let resolvedEventBus = eventBus ?? AppEventBus()
        let resolvedFolderManager = folderManager ?? LocalFolderManager(preferences: resolvedPreferences)
        let resolvedHotkeyManager = hotkeyManager ?? GlobalHotkeyManager(isIsolatedDevMode: detectedDevMode)
        let resolvedWebBridge = webBridge ?? GeminiWebBridge(folderManager: resolvedFolderManager)
        let resolvedWebViewModel = webViewModel ?? WebViewModel(
            preferences: resolvedPreferences,
            webBridge: resolvedWebBridge,
            isIsolatedDevMode: detectedDevMode
        )
        let resolvedWindowManager = windowManager ?? WindowManager(
            preferences: resolvedPreferences,
            webBridge: resolvedWebBridge
        )

        self.preferences = resolvedPreferences
        self.eventBus = resolvedEventBus
        self.folderManager = resolvedFolderManager
        self.hotkeyManager = resolvedHotkeyManager
        self.webBridge = resolvedWebBridge
        self.webViewModel = resolvedWebViewModel
        self.windowManager = resolvedWindowManager
        self.coordinator = AppCoordinator(
            webViewModel: resolvedWebViewModel,
            windowManager: resolvedWindowManager,
            preferences: resolvedPreferences,
            eventBus: resolvedEventBus,
            hotkeyManager: resolvedHotkeyManager
        )
    }

    /// Detecta dinámicamente si el proceso actual corresponde al paquete de desarrollo aislado.
    /// - Returns: Verdadero si la variable de entorno o el Bundle ID contienen firmas de desarrollo.
    private static func detectIsolatedDevEnvironment() -> Bool {
        if ProcessInfo.processInfo.environment["GEMINI_DEV_ISOLATED"] == "1" {
            return true
        }
        if let bundleID = Bundle.main.bundleIdentifier,
           bundleID.contains(".dev") || bundleID.contains(".arm64") {
            return true
        }
        return false
    }
}
