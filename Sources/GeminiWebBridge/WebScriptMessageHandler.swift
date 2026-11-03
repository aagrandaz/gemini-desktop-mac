//
//  WebScriptMessageHandler.swift
//  GeminiWebBridge
//
//  Autor: aagrandaz@gmail.com
//

import Foundation
import WebKit

/// Manejador desacoplado de mensajes de scripts (`WKScriptMessageHandler`) que analiza eventos provenientes del JavaScript inyectado y los delega a `GeminiWebBridging`.
public final class WebScriptMessageHandler: NSObject, WKScriptMessageHandler {
    /// Referencia débil al puente web para evitar ciclos de retención de memoria.
    public weak var webBridge: GeminiWebBridging?
    /// Referencia débil a la vista web emisora.
    public weak var webView: WKWebView?

    /// Inicializador del receptor de mensajes de WebKit.
    /// - Parameters:
    ///   - webBridge: Instancia conformante a `GeminiWebBridging`.
    ///   - webView: Instancia opcional de `WKWebView`.
    public init(webBridge: GeminiWebBridging? = nil, webView: WKWebView? = nil) {
        self.webBridge = webBridge
        self.webView = webView
    }

    /// Punto de entrada del protocolo `WKScriptMessageHandler` invocado por WebKit cuando JavaScript ejecuta `postMessage`.
    /// - Parameters:
    ///   - userContentController: Controlador de contenido asociado.
    ///   - message: Mensaje con el nombre del canal y el cuerpo remitido.
    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        if message.name == UserScripts.consoleLogHandler {
            if let body = message.body as? String {
                print("[WebView] \(body)")
            }
        } else if message.name == UserScripts.sparkFolderHandler {
            guard let body = message.body as? [String: Any],
                  let parsedAction = Self.parseSparkFolderAction(from: body) else { return }

            Task { @MainActor [weak self] in
                guard let self = self,
                      let bridge = self.webBridge,
                      let webView = self.webView else { return }
                bridge.handleSparkFolderAction(parsedAction, in: webView)
            }
        }
    }

    /// Decodifica de forma segura diccionarios no tipados provenientes de JavaScript a la enumeración fuertemente tipada `SparkFolderAction`.
    /// - Parameter body: Diccionario de datos del cuerpo del mensaje.
    /// - Returns: Una acción válida `SparkFolderAction`, o `nil` si el mensaje no cumple el formato esperado.
    public static func parseSparkFolderAction(from body: [String: Any]) -> SparkFolderAction? {
        guard let action = body["action"] as? String else { return nil }
        switch action {
        case "addFolder":
            return .addFolder
        case "removeFolder":
            guard let idString = body["id"] as? String,
                  let id = UUID(uuidString: idString) else { return nil }
            return .removeFolder(id)
        case "getConnectedFolders":
            return .getConnectedFolders
        case "attachFolderContext":
            guard let idString = body["id"] as? String,
                  let id = UUID(uuidString: idString) else { return nil }
            return .attachFolderContext(id)
        default:
            return nil
        }
    }
}
