//
//  GeminiWebView.swift
//  GeminiUI
//
//  Autor: aagrandaz@gmail.com
//

import SwiftUI
import WebKit
import AppKit

/// Puente `NSViewRepresentable` que integra una instancia compartida de `WKWebView` dentro de vistas SwiftUI.
/// Permite migrar el mismo WebView entre la ventana principal y la barra flotante (Flyweight Pattern).
public struct GeminiWebView: NSViewRepresentable {
    /// Instancia nativa de `WKWebView` administrada.
    public let webView: WKWebView

    /// Inicializador del puente de vista web.
    /// - Parameter webView: Instancia de `WKWebView` a presentar.
    public init(webView: WKWebView) {
        self.webView = webView
    }

    /// Crea el contenedor AppKit `WebViewContainer` que aloja la vista web.
    public func makeNSView(context: Context) -> WebViewContainer {
        WebViewContainer(webView: webView, coordinator: context.coordinator)
    }

    /// Actualiza la vista AppKit cuando cambian los datos de SwiftUI.
    public func updateNSView(_ container: WebViewContainer, context: Context) {}

    /// Genera el coordinador que implementa los delegados de navegación, interfaz y descargas de WebKit.
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Coordinador que implementa `WKNavigationDelegate`, `WKUIDelegate` y `WKDownloadDelegate`.
    public final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        /// URL de destino calculada para la descarga en curso.
        private var downloadDestination: URL?

        /// Gestiona la navegación de enlaces externos abriéndolos en el navegador predeterminado del sistema.
        public func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                if isExternalURL(url) {
                    NSWorkspace.shared.open(url)
                } else {
                    webView.load(URLRequest(url: url))
                }
            }
            return nil
        }

        /// Determina la política de navegación permitiendo descargas directas de archivos que WebKit no puede renderizar.
        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if navigationResponse.canShowMIMEType {
                decisionHandler(.allow)
            } else {
                decisionHandler(.download)
            }
        }

        /// Asocia el delegado de descarga cuando una respuesta se convierte en descarga.
        public func webView(
            _ webView: WKWebView,
            navigationResponse: WKNavigationResponse,
            didBecome download: WKDownload
        ) {
            download.delegate = self
        }

        /// Asocia el delegado de descarga cuando una acción de navegación se convierte en descarga.
        public func webView(
            _ webView: WKWebView,
            navigationAction: WKNavigationAction,
            didBecome download: WKDownload
        ) {
            download.delegate = self
        }

        /// Determina el destino final de guardado en la carpeta Descargas del usuario evitando colisiones de nombre.
        public func download(
            _ download: WKDownload,
            decideDestinationUsing response: URLResponse,
            suggestedFilename: String,
            completionHandler: @escaping (URL?) -> Void
        ) {
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            var destination = downloadsURL.appendingPathComponent(suggestedFilename)

            var counter = 1
            let fileManager = FileManager.default
            let nameWithoutExtension = destination.deletingPathExtension().lastPathComponent
            let fileExtension = destination.pathExtension

            while fileManager.fileExists(atPath: destination.path) {
                let newName = fileExtension.isEmpty
                    ? "\(nameWithoutExtension) (\(counter))"
                    : "\(nameWithoutExtension) (\(counter)).\(fileExtension)"
                destination = downloadsURL.appendingPathComponent(newName)
                counter += 1
            }

            downloadDestination = destination
            completionHandler(destination)
        }

        /// Revela el archivo descargado en el Finder al finalizar la descarga con éxito.
        public func downloadDidFinish(_ download: WKDownload) {
            guard let destination = downloadDestination else { return }
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        }

        /// Muestra una alerta nativa de error en caso de fallo durante la descarga.
        public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            let alert = NSAlert()
            alert.messageText = "Fallo en la descarga"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "Aceptar")
            alert.runModal()
        }

        /// Despliega paneles de alerta JavaScript con diálogos nativos de AppKit (`NSAlert`).
        public func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "Aceptar")
            alert.runModal()
            completionHandler()
        }

        /// Despliega paneles de confirmación JavaScript (Aceptar/Cancelar) con `NSAlert`.
        public func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            let alert = NSAlert()
            alert.messageText = message
            alert.addButton(withTitle: "Aceptar")
            alert.addButton(withTitle: "Cancelar")
            completionHandler(alert.runModal() == .alertFirstButtonReturn)
        }

        /// Despliega paneles de entrada de texto de JavaScript (prompt) con campo de texto nativo.
        public func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            let alert = NSAlert()
            alert.messageText = prompt
            alert.addButton(withTitle: "Aceptar")
            alert.addButton(withTitle: "Cancelar")

            let textField = NSTextField(frame: NSRect(
                x: 0,
                y: 0,
                width: GeminiWebView.Constants.textFieldWidth,
                height: GeminiWebView.Constants.textFieldHeight
            ))
            textField.stringValue = defaultText ?? ""
            alert.accessoryView = textField

            completionHandler(alert.runModal() == .alertFirstButtonReturn ? textField.stringValue : nil)
        }

        /// Concede automáticamente permisos de captura de medios para dominios confiables de Google.
        public func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            decisionHandler(origin.host.contains(GeminiWebView.Constants.trustedHost) ? .grant : .prompt)
        }

        /// Despliega el selector nativo de archivos (`NSOpenPanel`) cuando la web solicita subir documentos.
        public func webView(
            _ webView: WKWebView,
            runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping ([URL]?) -> Void
        ) {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = parameters.allowsMultipleSelection
            panel.canChooseDirectories = parameters.allowsDirectories
            panel.canChooseFiles = true
            NSApp.activate(ignoringOtherApps: true)
            panel.begin { response in
                completionHandler(response == .OK ? panel.urls : nil)
            }
        }

        /// Distingue entre dominios internos de Gemini/Google y enlaces web externos.
        private func isExternalURL(_ url: URL) -> Bool {
            guard let host = url.host?.lowercased() else { return false }
            let internalHosts = ["gemini.google.com", "accounts.google.com"]
            let internalSuffixes = [".googleapis.com", ".gstatic.com"]

            if internalHosts.contains(host) { return false }
            for suffix in internalSuffixes {
                if host.hasSuffix(suffix) { return false }
            }
            return true
        }
    }
}

/// Contenedor AppKit (`NSView`) que gestiona el acoplamiento y desacoplamiento dinámico de la instancia única de `WKWebView`.
public final class WebViewContainer: NSView {
    /// Instancia de la vista web.
    public let webView: WKWebView
    /// Coordinador con los delegados configurados.
    public let coordinator: GeminiWebView.Coordinator
    /// Observador de notificaciones de ventana activa.
    private var windowObserver: NSObjectProtocol?

    /// Inicializador del contenedor.
    /// - Parameters:
    ///   - webView: Instancia de `WKWebView`.
    ///   - coordinator: Coordinador con los delegados.
    public init(webView: WKWebView, coordinator: GeminiWebView.Coordinator) {
        self.webView = webView
        self.coordinator = coordinator
        super.init(frame: .zero)
        autoresizesSubviews = true
        setupWindowObserver()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Suscribe al evento de ventana convertida en clave para reaplicar el WebView a este contenedor si está visible.
    private func setupWindowObserver() {
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let keyWindow = notification.object as? NSWindow,
                  self.window === keyWindow else { return }
            self.attachWebView()
        }
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && window?.isKeyWindow == true {
            attachWebView()
        }
    }

    public override func layout() {
        super.layout()
        if webView.superview === self {
            webView.frame = bounds
        }
    }

    /// Acopla el `WKWebView` a la jerarquía de esta vista asegurando que solo exista un superview a la vez.
    private func attachWebView() {
        guard webView.superview !== self else { return }
        webView.removeFromSuperview()
        webView.frame = bounds
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        addSubview(webView)
    }
}

public extension GeminiWebView {
    /// Constantes de configuración de UI para diálogos y validación de hosts de `GeminiWebView`.
    struct Constants {
        /// Ancho del campo de texto de los paneles de diálogo prompt.
        public static let textFieldWidth: CGFloat = 200
        /// Alto del campo de texto de los paneles de diálogo prompt.
        public static let textFieldHeight: CGFloat = 24
        /// Host confiable para concesión directa de permisos de cámara y micrófono.
        public static let trustedHost = "google.com"
    }
}
