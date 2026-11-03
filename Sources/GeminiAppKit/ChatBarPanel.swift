//
//  ChatBarPanel.swift
//  GeminiAppKit
//
//  Autor: aagrandaz@gmail.com
//

import SwiftUI
import AppKit
import WebKit
import GeminiCore
import GeminiWebBridge

/// Panel flotante no activable (`NSPanel`) diseñado para la barra compacta de Gemini.
/// Permite enviar prompts rápidamente sin perder el foco de la ventana activa del usuario.
public final class ChatBarPanel: NSPanel, NSWindowDelegate {

    /// Almacén de preferencias inyectado.
    private let preferences: PreferencesStoring
    /// Puente web inyectado para evaluar el estado del chat y automatizar el DOM.
    private let webBridge: GeminiWebBridging

    /// Tamaño inicial de la ventana calculado a partir de las preferencias.
    private var initialSize: NSSize {
        let width = preferences.panelWidth
        let height = preferences.panelHeight
        return NSSize(
            width: width > 0 ? width : Constants.defaultWidth,
            height: height > 0 ? height : Constants.defaultHeight
        )
    }

    /// Pantalla activa que contiene el centro del panel flotante.
    private var currentScreen: NSScreen? {
        let panelCenter = NSPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screen(containing: panelCenter)
    }

    /// Altura calculada cuando la barra se expande al detectar un historial de conversación.
    private var expandedHeight: CGFloat {
        let screenHeight = currentScreen?.visibleFrame.height ?? 800
        return max(screenHeight * Constants.expandedScreenRatio, initialSize.height)
    }

    /// Estado de expansión del panel.
    private var isExpanded = false
    /// Temporizador de sondeo para detectar respuestas del modelo en la conversación.
    private var pollingTimer: Timer?
    /// Trabajo en cola con retardo para guardar la posición arrastrada sin sobrecargar el disco.
    private var positionSaveWork: DispatchWorkItem?
    /// Referencia débil al WebView contenido dentro de la jerarquía de vistas.
    private weak var webView: WKWebView?
    /// Monitor global de clics fuera de la ventana para cerrarla automáticamente.
    private var clickOutsideMonitor: Any?

    /// Inicializador del panel flotante.
    /// - Parameters:
    ///   - contentView: Vista AppKit que contiene la interfaz SwiftUI y el WebView.
    ///   - preferences: Repositorio de configuración.
    ///   - webBridge: Puente de comunicación web.
    public init(contentView: NSView, preferences: PreferencesStoring, webBridge: GeminiWebBridging) {
        self.preferences = preferences
        self.webBridge = webBridge

        let width = preferences.panelWidth
        let height = preferences.panelHeight
        let initWidth = width > 0 ? width : Constants.defaultWidth
        let initHeight = height > 0 ? height : Constants.defaultHeight

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: initWidth, height: initHeight),
            styleMask: [
                .nonactivatingPanel,
                .resizable,
                .borderless
            ],
            backing: .buffered,
            defer: false
        )

        self.contentView = contentView
        self.delegate = self

        configureWindow()
        configureAppearance()

        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.webViewSearchDelay) { [weak self] in
            guard let self = self, let content = self.contentView else { return }
            self.findWebView(in: content)
            self.startPolling()
        }
    }

    /// Inspecciona recursivamente la jerarquía de subvistas para hallar la referencia a `WKWebView`.
    /// - Parameter view: Vista raíz donde iniciar la búsqueda.
    private func findWebView(in view: NSView) {
        if let wk = view as? WKWebView {
            self.webView = wk
            return
        }
        for subview in view.subviews {
            findWebView(in: subview)
        }
    }

    /// Aplica las propiedades de ventana flotante, niveles de z-order y comportamientos de pantalla completa.
    private func configureWindow() {
        isFloatingPanel = true
        level = .popUpMenu
        isMovable = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false

        collectionBehavior.insert(.fullScreenAuxiliary)
        collectionBehavior.insert(.canJoinAllSpaces)

        minSize = NSSize(width: Constants.minWidth, height: Constants.minHeight)
        maxSize = NSSize(width: Constants.maxWidth, height: Constants.maxHeight)

        setupClickOutsideMonitor()
    }

    /// Configura el monitor global para ocultar el panel si el usuario hace clic fuera de su marco.
    private func setupClickOutsideMonitor() {
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let self = self, self.isVisible else { return }
            self.orderOut(nil)
        }
    }

    /// Configura sombras, esquinas redondeadas y bordes sutiles según las guías de diseño de macOS.
    private func configureAppearance() {
        hasShadow = true
        backgroundColor = .clear
        isOpaque = false

        if let contentView = contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = Constants.cornerRadius
            contentView.layer?.masksToBounds = true
            contentView.layer?.borderWidth = 1.0
            contentView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.4).cgColor
        }
    }

    /// Inicia el temporizador de sondeo periódico para detectar respuestas o conversaciones activas.
    private func startPolling() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.initialPollingDelay) { [weak self] in
            self?.pollingTimer = Timer.scheduledTimer(withTimeInterval: Constants.pollingInterval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.checkForConversation()
                }
            }
        }
    }

    /// Consulta el estado del DOM a través del puente web para decidir si el panel debe expandirse.
    private func checkForConversation() {
        guard !isExpanded else { return }
        guard let webView = webView else { return }

        webBridge.checkConversationState(in: webView) { [weak self] inConversation in
            if inConversation {
                self?.expandToNormalSize()
            }
        }
    }

    /// Anima suavemente el panel incrementando su altura para mostrar el hilo de mensajes.
    private func expandToNormalSize() {
        guard !isExpanded else { return }
        isExpanded = true
        pollingTimer?.invalidate()

        let currentFrame = self.frame
        guard let screen = currentScreen else { return }
        let visibleFrame = screen.visibleFrame
        let maxAvailableHeight = visibleFrame.maxY - currentFrame.origin.y

        let targetHeight = min(self.expandedHeight, maxAvailableHeight - Constants.topPadding)
        let clampedHeight = max(targetHeight, initialSize.height)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)

            let newFrame = NSRect(
                x: currentFrame.origin.x,
                y: currentFrame.origin.y,
                width: currentFrame.width,
                height: clampedHeight
            )
            self.animator().setFrame(newFrame, display: true)
        }
    }

    /// Restablece la barra de chat a su tamaño compacto inicial y reinicia el sondeo.
    public func resetToInitialSize() {
        isExpanded = false
        pollingTimer?.invalidate()

        let currentFrame = frame

        setFrame(NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y,
            width: currentFrame.width,
            height: initialSize.height
        ), display: true)

        startPolling()
    }

    /// Verifica el estado actual del contenido web y ajusta la altura según corresponda.
    public func checkAndAdjustSize() {
        guard let webView = webView else { return }

        focusInput()

        webBridge.checkConversationState(in: webView) { [weak self] inConversation in
            guard let self = self else { return }
            if inConversation {
                if !self.isExpanded {
                    self.expandToNormalSize()
                }
            } else {
                if self.isExpanded {
                    self.resetToInitialSize()
                }
            }
        }
    }

    /// Enfoca el cursor en el campo de texto web.
    public func focusInput() {
        guard let webView = webView else { return }
        webBridge.focusInput(in: webView)
    }

    deinit {
        pollingTimer?.invalidate()
        positionSaveWork?.cancel()
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - NSWindowDelegate

    /// Delegado invocado cuando el usuario redimensiona manualmente el panel.
    public func windowDidResize(_ notification: Notification) {
        guard !isExpanded else { return }
        preferences.panelWidth = frame.width
        preferences.panelHeight = frame.height
    }

    /// Delegado invocado cuando el usuario desplaza el panel para guardar las coordenadas con debounce.
    public func windowDidMove(_ notification: Notification) {
        guard preferences.panelPosition == .rememberLast else { return }
        positionSaveWork?.cancel()
        let origin = frame.origin
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                self.preferences.panelX = origin.x
                self.preferences.panelY = origin.y
            }
        }
        positionSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.positionSaveDebounce, execute: work)
    }

    // MARK: - Keyboard Handling

    /// Maneja la tecla Escape cerrando el panel flotante.
    public override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    /// Intercepta atajos de teclado clave, como Cmd+N para crear un nuevo chat.
    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) &&
           !event.modifierFlags.contains(.shift) &&
           !event.modifierFlags.contains(.option) &&
           event.charactersIgnoringModifiers == "n" {
            openNewChat()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Abre un nuevo chat y contrae el panel a su altura inicial.
    private func openNewChat() {
        guard let webView = webView else { return }
        webBridge.openNewChat(in: webView) { [weak self] in
            Task { @MainActor [weak self] in
                self?.resetToInitialSize()
            }
        }
    }

    /// Permite que el panel reciba foco de teclado.
    public override var canBecomeKey: Bool { true }
    /// Permite que el panel sea la ventana principal.
    public override var canBecomeMain: Bool { true }
}

public extension ChatBarPanel {
    /// Dimensiones y constantes de temporización para `ChatBarPanel`.
    struct Constants {
        /// Ancho por defecto del panel (500 pt).
        public static let defaultWidth: CGFloat = 500
        /// Alto por defecto del panel en estado compacto (200 pt).
        public static let defaultHeight: CGFloat = 200
        /// Ancho mínimo permitido.
        public static let minWidth: CGFloat = 300
        /// Alto mínimo permitido.
        public static let minHeight: CGFloat = 150
        /// Ancho máximo permitido.
        public static let maxWidth: CGFloat = 900
        /// Alto máximo permitido.
        public static let maxHeight: CGFloat = 900
        /// Radio de curvatura de esquinas redondeadas.
        public static let cornerRadius: CGFloat = 30
        /// Grosor del borde perimetral.
        public static let borderWidth: CGFloat = 0.5
        /// Proporción respecto a la pantalla visible al expandirse (70%).
        public static let expandedScreenRatio: CGFloat = 0.7
        /// Duración de animación de tamaño.
        public static let animationDuration: Double = 0.3
        /// Intervalo de sondeo periódico de conversación (1.0 s).
        public static let pollingInterval: TimeInterval = 1.0
        /// Retardo inicial antes de activar el sondeo (3.0 s).
        public static let initialPollingDelay: TimeInterval = 3.0
        /// Retardo antes de buscar el WebView en la jerarquía (0.5 s).
        public static let webViewSearchDelay: TimeInterval = 0.5
        /// Espacio libre superior al expandirse (20 pt).
        public static let topPadding: CGFloat = 20
        /// Tiempo de espera para consolidar el guardado de coordenadas en disco (0.3 s).
        public static let positionSaveDebounce: TimeInterval = 0.3
    }
}
