//
//  AppCoordinator.swift
//  GeminiDesktop
//
//  Autor: aagrandaz@gmail.com
//

import SwiftUI
import AppKit
import Observation
import GeminiCore
import GeminiWebBridge
import GeminiAppKit
import GeminiUI

/// Coordinador principal de la aplicación que implementa el patrón MVVM-C.
/// Orquesta la navegación, el ciclo de vida de las ventanas y los flujos de interacción de alto nivel (Single Responsibility Principle).
@Observable
@MainActor
public final class AppCoordinator {
    /// Modelo de navegación y estado de WebKit.
    public let webViewModel: WebViewModel
    /// Gestor responsable de las ventanas AppKit y paneles emergentes.
    public let windowManager: WindowManaging
    /// Repositorio de configuración y preferencias del usuario.
    public let preferences: PreferencesStoring
    /// Bus de eventos de la aplicación.
    public let eventBus: AppEventStreaming
    /// Administrador de combinaciones globales de teclas.
    private let hotkeyManager: HotkeyManaging
    /// Tarea asíncrona en segundo plano que procesa los eventos emitidos por el bus.
    @ObservationIgnored
    nonisolated(unsafe) private var eventTask: Task<Void, Never>?

    /// Indica si la ventana principal tiene activa la flotabilidad permanente (Always-on-Top).
    public var alwaysOnTop: Bool {
        preferences.alwaysOnTop
    }

    /// Inicializador con inyección de dependencias.
    /// - Parameters:
    ///   - webViewModel: Instancia de `WebViewModel`.
    ///   - windowManager: Gestor de ventanas conformante a `WindowManaging`.
    ///   - preferences: Repositorio conformante a `PreferencesStoring`.
    ///   - eventBus: Bus reactivo conformante a `AppEventStreaming`.
    ///   - hotkeyManager: Gestor de atajos conformante a `HotkeyManaging`.
    public init(
        webViewModel: WebViewModel,
        windowManager: WindowManaging,
        preferences: PreferencesStoring,
        eventBus: AppEventStreaming,
        hotkeyManager: HotkeyManaging
    ) {
        self.webViewModel = webViewModel
        self.windowManager = windowManager
        self.preferences = preferences
        self.eventBus = eventBus
        self.hotkeyManager = hotkeyManager

        setupEventStream()
        setupGlobalHotkey()
    }

    /// Configura la suscripción al flujo asíncrono de eventos de la aplicación.
    private func setupEventStream() {
        eventTask = Task { [weak self] in
            guard let self = self else { return }
            for await event in self.eventBus.stream() {
                guard !Task.isCancelled else { break }
                self.handle(event: event)
            }
        }
    }

    /// Registra la acción del atajo global para alternar la visibilidad de la barra de chat.
    private func setupGlobalHotkey() {
        hotkeyManager.registerDefaultShortcut { [weak self] in
            Task { @MainActor [weak self] in
                self?.toggleChatBar()
            }
        }
    }

    /// Procesa y despacha las acciones correspondientes a cada evento del bus.
    /// - Parameter event: Evento `AppEvent` recibido.
    public func handle(event: AppEvent) {
        switch event {
        case .openMainWindow:
            openMainWindow()
        case .openSettings, .toggleSidebar:
            break
        }
    }

    // MARK: - Window Routing

    /// Registra la acción `OpenWindowAction` provista por el entorno SwiftUI.
    /// - Parameter action: Clausura con el identificador de la ventana a abrir.
    public func registerOpenWindowAction(_ action: @escaping (String) -> Void) {
        windowManager.openWindowAction = action
    }

    /// Despliega el panel flotante de chat bar, instanciando la vista SwiftUI correspondiente.
    public func showChatBar() {
        windowManager.showChatBar { [weak self] in
            guard let self = self else { return NSView() }
            let view = ChatBarView(
                webView: self.webViewModel.wkWebView,
                onExpandToMain: { [weak self] in
                    self?.expandToMainWindow()
                }
            )
            return NSHostingView(rootView: view)
        }
    }

    /// Oculta el panel flotante de chat bar.
    public func hideChatBar() {
        windowManager.hideChatBar()
    }

    /// Alterna el estado de visibilidad del panel flotante de chat bar.
    public func toggleChatBar() {
        windowManager.toggleChatBar { [weak self] in
            guard let self = self else { return NSView() }
            let view = ChatBarView(
                webView: self.webViewModel.wkWebView,
                onExpandToMain: { [weak self] in
                    self?.expandToMainWindow()
                }
            )
            return NSHostingView(rootView: view)
        }
    }

    /// Transiciona el chat bar hacia la ventana principal en el mismo monitor.
    public func expandToMainWindow() {
        windowManager.expandToMainWindow()
    }

    /// Abre y enfoca la ventana principal de la aplicación.
    public func openMainWindow() {
        windowManager.openMainWindow(on: nil)
    }

    /// Trae la ventana principal al frente del sistema.
    public func bringMainWindowToFront() {
        windowManager.bringMainWindowToFront()
    }

    /// Alterna la configuración de Always-on-Top y la delega al gestor de ventanas.
    public func toggleAlwaysOnTop() {
        preferences.alwaysOnTop.toggle()
        windowManager.applyAlwaysOnTop(preferences.alwaysOnTop)
    }

    /// Configura la política de activación de macOS en el arranque (.regular o .accessory).
    public func configureLaunchPolicy() {
        windowManager.configureLaunchActivationPolicy()
    }

    /// Alias para compatibilidad con llamadas explícitas a la política de activación.
    public func configureLaunchActivationPolicy() {
        configureLaunchPolicy()
    }

    deinit {
        eventTask?.cancel()
    }
}
