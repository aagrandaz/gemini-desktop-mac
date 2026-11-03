//
//  GeminiWebBridge.swift
//  GeminiWebBridge
//
//  Autor: aagrandaz@gmail.com
//

import Foundation
import WebKit
import GeminiCore

/// Acciones tipadas enviadas desde los componentes web de Spark o la barra lateral inyectada.
public enum SparkFolderAction: Sendable, Equatable {
    /// Solicita abrir el selector nativo para conectar una nueva carpeta local.
    case addFolder
    /// Solicita remover una carpeta conectada dado su identificador único.
    case removeFolder(UUID)
    /// Solicita sincronizar la lista de carpetas conectadas hacia el DOM web.
    case getConnectedFolders
    /// Solicita inyectar el resumen contextual de los archivos de la carpeta en el cuadro de texto de Gemini.
    case attachFolderContext(UUID)
}

/// Contrato para la automatización de la interfaz DOM de Gemini y la comunicación bidireccional nativo-web.
@MainActor
public protocol GeminiWebBridging: AnyObject {
    /// Inicia un nuevo chat en la interfaz de Gemini simulando el atajo o interactuando con el DOM.
    /// - Parameters:
    ///   - webView: Instancia de `WKWebView` que aloja la sesión.
    ///   - completion: Clausura opcional que se ejecuta tras despachar el script.
    func openNewChat(in webView: WKWebView, completion: (() -> Void)?)

    /// Inyecta y envía un mensaje de texto en el campo de entrada de Gemini.
    /// - Parameters:
    ///   - text: Contenido del prompt a enviar.
    ///   - webView: Instancia de `WKWebView`.
    func submitPrompt(_ text: String, in webView: WKWebView)

    /// Sincroniza la lista de carpetas conectadas del sistema nativo con el script inyectado en el DOM.
    /// - Parameter webView: Instancia de `WKWebView`.
    func syncConnectedFoldersToWeb(in webView: WKWebView)

    /// Evalúa en el DOM si el usuario se encuentra actualmente en una conversación activa.
    /// - Parameters:
    ///   - webView: Instancia de `WKWebView`.
    ///   - completion: Clausura que recibe verdadero si hay mensajes en el historial.
    func checkConversationState(in webView: WKWebView, completion: @escaping (Bool) -> Void)

    /// Enfoca el cursor en el área de texto de entrada de Gemini.
    /// - Parameter webView: Instancia de `WKWebView`.
    func focusInput(in webView: WKWebView)

    /// Procesa una acción generada desde el JavaScript inyectado en la página web.
    /// - Parameters:
    ///   - action: Acción tipada `SparkFolderAction`.
    ///   - webView: Instancia de `WKWebView`.
    func handleSparkFolderAction(_ action: SparkFolderAction, in webView: WKWebView)
}

/// Implementación concreta de la automatización del DOM de Gemini y el puente de carpetas de Spark.
@MainActor
public final class GeminiWebBridge: GeminiWebBridging {
    /// Gestor de carpetas inyectado para realizar operaciones de lectura y selección.
    private let folderManager: FolderManaging

    /// Script JavaScript para disparar el atajo Cmd+Shift+O que inicia un nuevo chat en Gemini.
    private static let openNewChatScript = """
    (function() {
        const event = new KeyboardEvent('keydown', {
            key: 'O',
            code: 'KeyO',
            keyCode: 79,
            which: 79,
            shiftKey: true,
            metaKey: true,
            bubbles: true,
            cancelable: true,
            composed: true
        });
        document.activeElement.dispatchEvent(event);
        document.dispatchEvent(event);
    })();
    """

    /// Script JavaScript para inspeccionar si existen elementos de respuesta o historial de chat en el DOM.
    private static let checkConversationScript = """
    (function() {
        const scroller = document.querySelector('infinite-scroller[data-test-id="chat-history-container"]');
        if (!scroller) { return false; }
        const hasResponseContainer = scroller.querySelector('response-container') !== null;
        const hasRatingButtons = scroller.querySelector('[aria-label="Good response"], [aria-label="Bad response"]') !== null;
        return hasResponseContainer || hasRatingButtons;
    })();
    """

    /// Script JavaScript para transferir el foco del teclado al campo de entrada principal de Gemini.
    private static let focusInputScript = """
    (function() {
        const input = document.querySelector('rich-textarea[aria-label="Enter a prompt here"]') ||
                      document.querySelector('[contenteditable="true"]') ||
                      document.querySelector('textarea');
        if (input) {
            input.focus();
            return true;
        }
        return false;
    })();
    """

    /// Inicializador con inyección de dependencias.
    /// - Parameter folderManager: Instancia conformante a `FolderManaging`.
    public init(folderManager: FolderManaging) {
        self.folderManager = folderManager
    }

    /// Ejecuta el script de apertura de nuevo chat en la vista web.
    public func openNewChat(in webView: WKWebView, completion: (() -> Void)? = nil) {
        webView.evaluateJavaScript(Self.openNewChatScript) { _, _ in
            completion?()
        }
    }

    /// Rellena el campo de texto de Gemini con el prompt indicado y simula el clic en el botón de envío.
    public func submitPrompt(_ text: String, in webView: WKWebView) {
        guard let jsonString = try? String(data: JSONEncoder().encode(text), encoding: .utf8) else { return }
        let script = """
        (function() {
            const promptText = \(jsonString);
            const input = document.querySelector('rich-textarea p') || document.querySelector('textarea') || document.querySelector('[contenteditable="true"]');
            if (input) {
                input.focus();
                if (input.tagName === 'TEXTAREA' || input.tagName === 'INPUT') {
                    input.value = promptText;
                } else {
                    input.textContent = promptText;
                }
                input.dispatchEvent(new Event('input', { bubbles: true }));
                setTimeout(() => {
                    const sendBtn = document.querySelector('button[aria-label*="Enviar"]') || document.querySelector('button.send-button') || document.querySelector('button[aria-label*="Send"]');
                    if (sendBtn) sendBtn.click();
                }, 300);
            }
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    /// Serializa las carpetas conectadas actuales e invoca la función de actualización en el entorno JavaScript.
    public func syncConnectedFoldersToWeb(in webView: WKWebView) {
        let folders = folderManager.folders
        let items: [[String: Any]] = folders.map { folder in
            [
                "id": folder.id.uuidString,
                "name": folder.name,
                "path": folder.path,
                "fileCount": folder.fileCount
            ]
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: items),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        let script = "window.__updateConnectedFolders && window.__updateConnectedFolders(\(jsonString));"
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    /// Verifica de manera asíncrona en el hilo principal si la conversación tiene contenido.
    public func checkConversationState(in webView: WKWebView, completion: @escaping (Bool) -> Void) {
        webView.evaluateJavaScript(Self.checkConversationScript) { result, _ in
            let inConversation = (result as? Bool) ?? false
            DispatchQueue.main.async {
                completion(inConversation)
            }
        }
    }

    /// Coloca el foco en el campo de texto de la página web.
    public func focusInput(in webView: WKWebView) {
        webView.evaluateJavaScript(Self.focusInputScript, completionHandler: nil)
    }

    /// Enruta las acciones provenientes de la interfaz web hacia los servicios nativos correspondientes.
    public func handleSparkFolderAction(_ action: SparkFolderAction, in webView: WKWebView) {
        switch action {
        case .addFolder:
            folderManager.addFolderFromPicker()
            syncConnectedFoldersToWeb(in: webView)
        case .removeFolder(let id):
            folderManager.removeFolder(id: id)
            syncConnectedFoldersToWeb(in: webView)
        case .getConnectedFolders:
            syncConnectedFoldersToWeb(in: webView)
        case .attachFolderContext(let id):
            if let folder = folderManager.folders.first(where: { $0.id == id }) {
                let summary = folderManager.generateContextSummary(for: folder)
                submitPrompt("Contexto de la carpeta conectada '\(folder.name)':\n\(summary)\n", in: webView)
            }
        }
    }
}
