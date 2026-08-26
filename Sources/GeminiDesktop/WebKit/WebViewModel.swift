//
//  WebViewModel.swift
//  GeminiDesktop
//
//  Created by alexcding on 2025-12-15.
//

import WebKit
import Combine
import AppKit

/// Handles script messages from JavaScript
class WebScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var webViewModel: WebViewModel?

    init(webViewModel: WebViewModel?) {
        self.webViewModel = webViewModel
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == UserScripts.consoleLogHandler {
            if let body = message.body as? String {
                print("[WebView] \(body)")
            }
        } else if message.name == UserScripts.sparkFolderHandler {
            guard let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }

            Task { @MainActor in
                guard let vm = self.webViewModel else { return }
                switch action {
                case "addFolder":
                    LocalFolderManager.shared.addFolderFromPicker()
                    vm.syncConnectedFoldersToWeb()
                case "removeFolder":
                    if let idString = body["id"] as? String, let id = UUID(uuidString: idString) {
                        LocalFolderManager.shared.removeFolder(id: id)
                        vm.syncConnectedFoldersToWeb()
                    }
                case "getConnectedFolders":
                    vm.syncConnectedFoldersToWeb()
                case "attachFolderContext":
                    if let idString = body["id"] as? String, let id = UUID(uuidString: idString) {
                        if let folder = LocalFolderManager.shared.folders.first(where: { $0.id == id }) {
                            let summary = LocalFolderManager.shared.generateContextSummary(for: folder)
                            vm.submitPrompt("Contexto de la carpeta conectada '\(folder.name)':\n\(summary)\n")
                        }
                    }
                default:
                    break
                }
            }
        }
    }
}

/// Observable wrapper around WKWebView with Gemini-specific functionality
@Observable
class WebViewModel {

    // MARK: - Constants

    static let geminiURL = URL(string: "https://gemini.google.com/app")!
    static let defaultPageZoom: Double = 1.0

    private static let geminiHost = "gemini.google.com"
    private static let geminiAppPath = "/app"
    private static var userAgent: String { UserAgentOption.currentUserAgentString }
    private static let minZoom: Double = 0.6
    private static let maxZoom: Double = 1.4

    // MARK: - Public Properties

    let wkWebView: WKWebView
    private(set) var canGoBack: Bool = false
    private(set) var canGoForward: Bool = false
    private(set) var isAtHome: Bool = true
    private(set) var isLoading: Bool = true

    // MARK: - Private Properties

    private var backObserver: NSKeyValueObservation?
    private var forwardObserver: NSKeyValueObservation?
    private var urlObserver: NSKeyValueObservation?
    private var loadingObserver: NSKeyValueObservation?
    private var scriptHandler: WebScriptMessageHandler?

    // MARK: - Initialization

    init() {
        let handler = WebScriptMessageHandler(webViewModel: nil)
        self.wkWebView = Self.createWebView(scriptHandler: handler)
        self.scriptHandler = handler
        handler.webViewModel = self
        setupObservers()
        loadHome()
    }

    // MARK: - Navigation

    func loadHome() {
        isAtHome = true
        canGoBack = false
        wkWebView.load(URLRequest(url: Self.geminiURL))
    }

    func loadURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        isAtHome = false
        wkWebView.load(URLRequest(url: url))
    }

    func goBack() {
        isAtHome = false
        wkWebView.goBack()
    }

    func goForward() {
        wkWebView.goForward()
    }

    func reload() {
        wkWebView.reload()
    }

    func openNewChat() {
        let script = """
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
        wkWebView.evaluateJavaScript(script, completionHandler: nil)
    }

    func submitPrompt(_ text: String) {
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
        wkWebView.evaluateJavaScript(script, completionHandler: nil)
    }

    @MainActor
    func syncConnectedFoldersToWeb() {
        let folders = LocalFolderManager.shared.folders
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
        wkWebView.evaluateJavaScript(script, completionHandler: nil)
    }

    // MARK: - Zoom

    func zoomIn() {
        let newZoom = min((wkWebView.pageZoom * 100 + 1).rounded() / 100, Self.maxZoom)
        setZoom(newZoom)
    }

    func zoomOut() {
        let newZoom = max((wkWebView.pageZoom * 100 - 1).rounded() / 100, Self.minZoom)
        setZoom(newZoom)
    }

    func resetZoom() {
        setZoom(Self.defaultPageZoom)
    }

    private func setZoom(_ zoom: Double) {
        wkWebView.pageZoom = zoom
        UserDefaults.standard.set(zoom, forKey: UserDefaultsKeys.pageZoom.rawValue)
    }

    func applyUserAgent() {
        let newUA = Self.userAgent
        guard wkWebView.customUserAgent != newUA else { return }
        wkWebView.customUserAgent = newUA
        wkWebView.reload()
    }

    // MARK: - Private Setup

    private static func createWebView(scriptHandler: WebScriptMessageHandler) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // Add user scripts
        for script in UserScripts.createAllScripts() {
            configuration.userContentController.addUserScript(script)
        }

        // Register message handlers
        #if DEBUG
        configuration.userContentController.add(scriptHandler, name: UserScripts.consoleLogHandler)
        #endif
        configuration.userContentController.add(scriptHandler, name: UserScripts.sparkFolderHandler)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.customUserAgent = userAgent

        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }

        let savedZoom = UserDefaults.standard.double(forKey: UserDefaultsKeys.pageZoom.rawValue)
        webView.pageZoom = savedZoom > 0 ? savedZoom : defaultPageZoom

        return webView
    }

    private func setupObservers() {
        backObserver = wkWebView.observe(\.canGoBack, options: [.new, .initial]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.canGoBack = !self.isAtHome && webView.canGoBack
            }
        }

        forwardObserver = wkWebView.observe(\.canGoForward, options: [.new, .initial]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.canGoForward = webView.canGoForward
            }
        }

        loadingObserver = wkWebView.observe(\.isLoading, options: [.new, .initial]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = webView.isLoading
                if !webView.isLoading {
                    self.syncConnectedFoldersToWeb()
                }
            }
        }

        urlObserver = wkWebView.observe(\.url, options: .new) { [weak self] webView, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let currentURL = webView.url else { return }

                // Force Safari UA during Google Login to support Passkeys and bypass security blocks
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
    }

    deinit {
        backObserver?.invalidate()
        forwardObserver?.invalidate()
        loadingObserver?.invalidate()
        urlObserver?.invalidate()
    }
}
