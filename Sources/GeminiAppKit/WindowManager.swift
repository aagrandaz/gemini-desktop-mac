//
//  WindowManager.swift
//  GeminiAppKit
//
//  Autor: aagrandaz@gmail.com
//

import AppKit
import SwiftUI
import GeminiCore
import GeminiWebBridge

/// Contrato para la presentación, posicionamiento y gestión del ciclo de vida de ventanas AppKit y paneles emergentes.
@MainActor
public protocol WindowManaging: AnyObject {
    /// Clausura que delega la apertura de ventanas SwiftUI mediante `OpenWindowAction`.
    var openWindowAction: ((String) -> Void)? { get set }

    /// Muestra o crea el panel flotante de chat bar inyectando la vista provista.
    /// - Parameter contentViewProvider: Factoría que retorna la vista de contenido `NSView`.
    func showChatBar(contentViewProvider: () -> NSView)

    /// Oculta el panel flotante de chat bar de la pantalla.
    func hideChatBar()

    /// Alterna la visibilidad (mostrar/ocultar) del panel flotante de chat bar.
    /// - Parameter contentViewProvider: Factoría que retorna la vista de contenido `NSView`.
    func toggleChatBar(contentViewProvider: () -> NSView)

    /// Restablece la posición del panel flotante según la opción configurada en preferencias.
    func resetChatBarPosition()

    /// Transiciona desde el panel flotante hacia la ventana principal maximizada en la misma pantalla.
    func expandToMainWindow()

    /// Abre y enfoca la ventana principal, opcionalmente centrándola en la pantalla indicada.
    /// - Parameter targetScreen: Pantalla de destino opcional.
    func openMainWindow(on targetScreen: NSScreen?)

    /// Cierra u oculta todas las instancias abiertas de la ventana principal.
    func closeMainWindow()

    /// Trae al frente la ventana principal y activa la aplicación.
    func bringMainWindowToFront()

    /// Aplica el nivel de flotabilidad Always-on-Top a la ventana principal.
    /// - Parameter alwaysOnTop: Si es verdadero, fija el nivel de ventana a `.floating`.
    func applyAlwaysOnTop(_ alwaysOnTop: Bool)

    /// Ajusta la política de activación de `NSApplication` (.regular vs .accessory) según las preferencias de inicio.
    func configureLaunchActivationPolicy()
}

/// Administrador y presentador de ventanas nativas AppKit que aísla la manipulación de `NSWindow` de la lógica de coordinación.
@MainActor
public final class WindowManager: WindowManaging {

    /// Constantes de configuración visual y temporización del gestor de ventanas.
    public struct Constants {
        /// Margen en puntos desde el Dock o borde inferior de la pantalla.
        public static let dockOffset: CGFloat = 50
        /// Identificador de la ventana principal en SwiftUI.
        public static let mainWindowIdentifier = "main"
        /// Título de la ventana principal de la aplicación.
        public static let mainWindowTitle = "Gemini Desktop"
        /// Retardo breve para ocultar la ventana durante el ciclo de arranque silencioso.
        public static let hideWindowDelay: TimeInterval = 0.1
    }

    /// Referencia al panel flotante de chat activo.
    private var chatBar: ChatBarPanel?
    /// Repositorio de preferencias inyectado.
    private let preferences: PreferencesStoring
    /// Puente web inyectado para delegar eventos del panel.
    private let webBridge: GeminiWebBridging

    /// Acción de apertura de ventanas de SwiftUI registrada por el coordinador.
    public var openWindowAction: ((String) -> Void)?

    /// Inicializador con inyección de dependencias.
    /// - Parameters:
    ///   - preferences: Repositorio de preferencias de la aplicación.
    ///   - webBridge: Puente de comunicación web de Gemini.
    public init(preferences: PreferencesStoring, webBridge: GeminiWebBridging) {
        self.preferences = preferences
        self.webBridge = webBridge
    }

    // MARK: - Chat Bar Presentation

    /// Muestra la barra flotante de chat, cerrando primero la ventana principal para evitar colisiones visuales.
    public func showChatBar(contentViewProvider: () -> NSView) {
        closeMainWindow()

        let position = preferences.panelPosition

        if let bar = chatBar {
            if position != .rememberLast {
                positionChatBar(bar, position: position)
            }
            bar.makeKeyAndOrderFront(nil)
            bar.checkAndAdjustSize()
            return
        }

        let contentView = contentViewProvider()
        let bar = ChatBarPanel(
            contentView: contentView,
            preferences: preferences,
            webBridge: webBridge
        )

        positionChatBar(bar, position: position)
        bar.makeKeyAndOrderFront(nil)
        chatBar = bar
    }

    /// Oculta el panel flotante de la pantalla.
    public func hideChatBar() {
        chatBar?.orderOut(nil)
    }

    /// Alterna el estado de visibilidad del panel flotante.
    public func toggleChatBar(contentViewProvider: () -> NSView) {
        if let bar = chatBar, bar.isVisible {
            hideChatBar()
        } else {
            showChatBar(contentViewProvider: contentViewProvider)
        }
    }

    /// Reposiciona el panel flotante según la opción configurada en las preferencias.
    public func resetChatBarPosition() {
        guard let bar = chatBar else { return }
        positionChatBar(bar, position: preferences.panelPosition)
    }

    /// Oculta la barra de chat y abre la ventana principal centrada en el monitor donde se encontraba el panel.
    public func expandToMainWindow() {
        let targetScreen = chatBar.flatMap { bar -> NSScreen? in
            let center = NSPoint(x: bar.frame.midX, y: bar.frame.midY)
            return NSScreen.screen(containing: center)
        } ?? NSScreen.main

        hideChatBar()
        openMainWindow(on: targetScreen)
    }

    /// Calcula y aplica las coordenadas del panel en la pantalla activa.
    private func positionChatBar(_ bar: ChatBarPanel, position: PanelPosition) {
        guard let screen = NSScreen.screenAtMouseLocation() ?? NSScreen.main else { return }

        if position == .rememberLast,
           let savedX = preferences.panelX,
           let savedY = preferences.panelY {
            let saved = NSPoint(x: savedX, y: savedY)
            let center = NSPoint(x: saved.x + bar.frame.width / 2, y: saved.y + bar.frame.height / 2)
            if NSScreen.screenStrictly(containing: center) != nil {
                bar.setFrameOrigin(saved)
                return
            }
        }

        let origin = screen.point(for: bar.frame.size, position: position, dockOffset: Constants.dockOffset)
        bar.setFrameOrigin(origin)
    }

    // MARK: - Main Window Management

    /// Trae al frente la ventana principal enfocando la aplicación.
    public func bringMainWindowToFront() {
        openMainWindow(on: nil)
    }

    /// Abre o enfoca la ventana principal, ajustando la política del Dock y la pantalla destino.
    public func openMainWindow(on targetScreen: NSScreen? = nil) {
        hideChatBar()

        if !preferences.hideDockIcon {
            NSApp?.setActivationPolicy(.regular)
        }

        if let window = findMainWindow() {
            if let screen = targetScreen {
                centerWindow(window, on: screen)
            }
            window.makeKeyAndOrderFront(nil)
        } else if let openWindowAction = openWindowAction {
            openWindowAction(Constants.mainWindowIdentifier)
            if let screen = targetScreen {
                centerNewlyCreatedWindow(on: screen)
            }
        }

        applyAlwaysOnTop(preferences.alwaysOnTop)
        NSApp?.activate(ignoringOtherApps: true)
    }

    /// Cierra u oculta todas las instancias regulares de la ventana principal.
    public func closeMainWindow() {
        guard let windows = NSApp?.windows else { return }
        for window in windows {
            if window.identifier?.rawValue == Constants.mainWindowIdentifier || window.title == Constants.mainWindowTitle {
                if !(window is NSPanel) {
                    window.orderOut(nil)
                }
            }
        }
    }

    /// Establece el nivel de ventana para mantenerla siempre por encima de otras aplicaciones.
    public func applyAlwaysOnTop(_ alwaysOnTop: Bool) {
        let level: NSWindow.Level = alwaysOnTop ? .floating : .normal
        if let mainWindow = findMainWindow() {
            mainWindow.level = level
        }
    }

    /// Configura si la aplicación opera como accesorio de menú o con presencia completa en el Dock al iniciar.
    public func configureLaunchActivationPolicy() {
        let hideWindowAtLaunch = preferences.hideWindowAtLaunch
        let hideDockIcon = preferences.hideDockIcon

        if hideDockIcon || hideWindowAtLaunch {
            NSApp?.setActivationPolicy(.accessory)
            if hideWindowAtLaunch {
                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.hideWindowDelay) { [weak self] in
                    self?.closeMainWindow()
                }
            }
        } else {
            NSApp?.setActivationPolicy(.regular)
        }
    }

    // MARK: - Private Helpers

    /// Localiza la ventana principal entre las ventanas abiertas de `NSApplication`.
    private func findMainWindow() -> NSWindow? {
        NSApp?.windows.first {
            $0.identifier?.rawValue == Constants.mainWindowIdentifier || $0.title == Constants.mainWindowTitle
        }
    }

    /// Centra la ventana especificada en el marco visible de la pantalla dada.
    private func centerWindow(_ window: NSWindow, on screen: NSScreen) {
        let origin = screen.centerPoint(for: window.frame.size)
        window.setFrameOrigin(origin)
    }

    /// Espera de forma asíncrona a que SwiftUI instancie la ventana para luego centrarla y aplicarle configuraciones.
    private func centerNewlyCreatedWindow(on screen: NSScreen, attempt: Int = 1) {
        let maxAttempts = 5
        let retryDelay = 0.05

        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
            guard let self = self else { return }

            if let window = self.findMainWindow() {
                self.centerWindow(window, on: screen)
                self.applyAlwaysOnTop(self.preferences.alwaysOnTop)
            } else if attempt < maxAttempts {
                self.centerNewlyCreatedWindow(on: screen, attempt: attempt + 1)
            }
        }
    }
}
