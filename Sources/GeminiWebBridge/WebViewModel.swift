//
//  WebViewModel.swift
//  GeminiWebBridge
//
//  Autor: aagrandaz@gmail.com
//

import Foundation
import WebKit
import Observation
import GeminiCore

/// Controlador observable que administra el ciclo de vida de `WKWebView`, navegación, factor de escala (zoom) y flujos reactivos de estado.
@Observable
@MainActor
public final class WebViewModel {

    // MARK: - Constants

    /// URL principal del servicio de Gemini Web.
    public static let geminiURL = URL(string: "https://gemini.google.com/app")!
    /// Nivel de escala visual estándar (100%).
    public static let defaultPageZoom: Double = 1.0
    /// Identificador UUID asignado al almacén de datos web para pruebas aisladas de desarrollo.
    private static let devDataStoreUUID = UUID(uuidString: "D4E5F6A7-B8C9-4012-9345-6789ABCDEF01")!

    /// Nombre de host de Gemini.
    private static let geminiHost = "gemini.google.com"
    /// Ruta base de la aplicación de Gemini.
    private static let geminiAppPath = "/app"
    /// Nivel mínimo de reducción visual permitido (60%).
    private static let minZoom: Double = 0.6
    /// Nivel máximo de ampliación visual permitido (140%).
    private static let maxZoom: Double = 1.4

    // MARK: - Public Properties

    /// Instancia nativa subyacente de `WKWebView`.
    public let wkWebView: WKWebView
    /// Instancia del puente de automatización web.
    public let webBridge: GeminiWebBridging
    /// Indica si el navegador tiene historial para navegar hacia atrás.
    public private(set) var canGoBack: Bool = false
    /// Indica si el navegador tiene historial para navegar hacia adelante.
    public private(set) var canGoForward: Bool = false
    /// Indica si la vista se encuentra actualmente en la pantalla de inicio principal de Gemini.
    public private(set) var isAtHome: Bool = true
    /// Indica si una página web está en proceso de carga activa.
    public private(set) var isLoading: Bool = true

    // MARK: - Private Properties

    /// Almacén de preferencias inyectado.
    private let preferences: PreferencesStoring
    /// Manejador de mensajes de script WebKit.
    private let scriptHandler: WebScriptMessageHandler
    /// Tareas asíncronas de observación KVO desacopladas del ciclo de vida.
    @ObservationIgnored
    nonisolated(unsafe) private var observationTasks: [Task<Void, Never>] = []

    // MARK: - Initialization

    /// Inicializa el modelo de la vista web inyectando dependencias y configurando observadores.
    /// - Parameters:
    ///   - preferences: Almacén de configuración de la app.
    ///   - webBridge: Puente de integración web nativa.
    ///   - isIsolatedDevMode: Si es verdadero, utiliza una cookie jar / almacén de datos aislado con UUID dedicado.
    public init(
        preferences: PreferencesStoring,
        webBridge: GeminiWebBridging,
        isIsolatedDevMode: Bool = false
    ) {
        self.preferences = preferences
        self.webBridge = webBridge

        let handler = WebScriptMessageHandler(webBridge: webBridge, webView: nil)
        let createdWebView = Self.createWebView(
            scriptHandler: handler,
            preferences: preferences,
            isIsolatedDevMode: isIsolatedDevMode
        )
        self.wkWebView = createdWebView
        self.scriptHandler = handler
        handler.webView = createdWebView

        startStateObservationStreams()
        loadHome()
    }

    // MARK: - Navigation

    /// Carga la URL de inicio oficial de Gemini en la vista web.
    public func loadHome() {
        isAtHome = true
        canGoBack = false
        wkWebView.load(URLRequest(url: Self.geminiURL))
    }

    /// Carga una dirección URL arbitraria a partir de una cadena.
    /// - Parameter urlString: Dirección web de destino.
    public func loadURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        isAtHome = false
        wkWebView.load(URLRequest(url: url))
    }

    /// Retrocede a la página previa en el historial de navegación de WebKit.
    public func goBack() {
        isAtHome = false
        wkWebView.goBack()
    }

    /// Avanza a la página siguiente en el historial de navegación de WebKit.
    public func goForward() {
        wkWebView.goForward()
    }

    /// Recarga el contenido de la página actual.
    public func reload() {
        wkWebView.reload()
    }

    // MARK: - Gemini Bridge Forwarding

    /// Solicita abrir un nuevo hilo de conversación a través del puente web.
    public func openNewChat() {
        webBridge.openNewChat(in: wkWebView, completion: nil)
    }

    /// Envía un texto de solicitud directamente al cuadro de entrada de Gemini.
    /// - Parameter text: Texto a procesar.
    public func submitPrompt(_ text: String) {
        webBridge.submitPrompt(text, in: wkWebView)
    }

    /// Sincroniza las carpetas locales conectadas hacia los componentes visuales inyectados en el DOM.
    public func syncConnectedFoldersToWeb() {
        webBridge.syncConnectedFoldersToWeb(in: wkWebView)
    }

    // MARK: - Zoom & User Agent

    /// Incrementa la escala visual de la página en un 1%.
    public func zoomIn() {
        let newZoom = min((wkWebView.pageZoom * 100 + 1).rounded() / 100, Self.maxZoom)
        setZoom(newZoom)
    }

    /// Reduce la escala visual de la página en un 1%.
    public func zoomOut() {
        let newZoom = max((wkWebView.pageZoom * 100 - 1).rounded() / 100, Self.minZoom)
        setZoom(newZoom)
    }

    /// Restablece el factor de escala visual al valor por defecto (100%).
    public func resetZoom() {
        setZoom(Self.defaultPageZoom)
    }

    /// Establece un factor de zoom específico tanto en el WebView como en las preferencias persistidas.
    /// - Parameter zoom: Factor decimal (ej. 1.0 para 100%).
    public func setZoom(_ zoom: Double) {
        wkWebView.pageZoom = zoom
        preferences.pageZoom = zoom
    }

    /// Aplica la cadena de User-Agent actual registrada en preferencias y recarga la página.
    public func applyUserAgent() {
        let newUA = preferences.currentUserAgentString
        guard wkWebView.customUserAgent != newUA else { return }
        wkWebView.customUserAgent = newUA
        wkWebView.reload()
    }

    // MARK: - Private Setup

    /// Construye y configura una nueva instancia de `WKWebView` con scripts de usuario y data store apropiados.
    private static func createWebView(
        scriptHandler: WebScriptMessageHandler,
        preferences: PreferencesStoring,
        isIsolatedDevMode: Bool
    ) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        if isIsolatedDevMode {
            configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: devDataStoreUUID)
        } else {
            configuration.websiteDataStore = .default()
        }
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        for script in UserScripts.createAllScripts() {
            configuration.userContentController.addUserScript(script)
        }

        #if DEBUG
        configuration.userContentController.add(scriptHandler, name: UserScripts.consoleLogHandler)
        #endif
        configuration.userContentController.add(scriptHandler, name: UserScripts.sparkFolderHandler)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.customUserAgent = preferences.currentUserAgentString

        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }

        let savedZoom = preferences.pageZoom
        webView.pageZoom = savedZoom > 0 ? savedZoom : defaultPageZoom

        return webView
    }

    /// Inicia tareas asíncronas para observar propiedades KVO de WebKit (`canGoBack`, `canGoForward`, `isLoading`, `url`).
    private func startStateObservationStreams() {
        let webView = wkWebView

        let backTask = Task { [weak self] in
            for await canBack in webView.publisher(for: \.canGoBack, options: [.initial, .new]).values {
                guard let self = self else { break }
                self.canGoBack = !self.isAtHome && canBack
            }
        }

        let forwardTask = Task { [weak self] in
            for await canForward in webView.publisher(for: \.canGoForward, options: [.initial, .new]).values {
                guard let self = self else { break }
                self.canGoForward = canForward
            }
        }

        let loadingTask = Task { [weak self] in
            for await loading in webView.publisher(for: \.isLoading, options: [.initial, .new]).values {
                guard let self = self else { break }
                self.isLoading = loading
                if !loading {
                    self.syncConnectedFoldersToWeb()
                }
            }
        }

        let urlTask = Task { [weak self] in
            for await currentURL in webView.publisher(for: \.url, options: [.new]).values {
                guard let self = self, let currentURL else { continue }

                if currentURL.host?.contains("accounts.google.com") == true {
                    if webView.customUserAgent != UserAgentOption.safariUA {
                        webView.customUserAgent = UserAgentOption.safariUA
                    }
                }

                let isGeminiApp = currentURL.host == Self.geminiHost &&
                                  currentURL.path.hasPrefix(Self.geminiAppPath)

                if isGeminiApp {
                    self.isAtHome = true
                    self.canGoBack = false
                } else {
                    self.isAtHome = false
                    self.canGoBack = webView.canGoBack
                }
            }
        }

        observationTasks = [backTask, forwardTask, loadingTask, urlTask]
    }

    deinit {
        for task in observationTasks {
            task.cancel()
        }
    }
}
