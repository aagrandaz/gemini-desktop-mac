//
//  UserScripts.swift
//  GeminiWebBridge
//
//  Autor: aagrandaz@gmail.com
//

import WebKit

/// Colección de scripts y hojas de estilo CSS inyectadas en la sesión de `WKWebView`.
/// Contiene parches de compatibilidad de teclado IME, estilos visuales y la interfaz inyectada de Spark.
public enum UserScripts {

    /// Nombre del canal de mensajes WebKit para depuración por consola en compilaciones DEBUG.
    public static let consoleLogHandler = "consoleLog"
    /// Nombre del canal de mensajes WebKit para la interacción con la sección de Carpetas Conectadas de Spark.
    public static let sparkFolderHandler = "sparkFolderHandler"

    /// Construye y retorna el conjunto completo de `WKUserScript` listos para añadirse al `WKUserContentController`.
    /// - Returns: Arreglo de scripts de usuario configurados con su tiempo de inyección y ámbito de frames.
    public static func createAllScripts() -> [WKUserScript] {
        var scripts: [WKUserScript] = [
            createIMEFixScript(),
            createWindowDragScript(),
            createSparkFolderBridgeScript()
        ]

        #if DEBUG
        scripts.insert(createConsoleLogBridgeScript(), at: 0)
        #endif

        return scripts
    }

    /// Genera el script que redirige llamadas de `console.log` hacia el canal nativo de WebKit en modo DEBUG.
    private static func createConsoleLogBridgeScript() -> WKUserScript {
        WKUserScript(
            source: consoleLogBridgeSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }

    /// Genera el script que intercepta y previene el envío prematuro de prompts durante la composición de caracteres complejos (IME / CJK).
    private static func createIMEFixScript() -> WKUserScript {
        WKUserScript(
            source: imeFixSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    }

    /// Genera el script de estilización CSS para tipografía moderna de Google Sans y dimensiones responsivas.
    private static func createWindowDragScript() -> WKUserScript {
        let source = """
        (function() {
            if (window.location.hostname.includes('accounts.google.com')) return;

            const style = document.createElement('style');
            style.textContent = `
                body, button, input, textarea, select {
                    font-family: 'Google Sans', -apple-system, BlinkMacSystemFont, 'Apple Color Emoji', 'Segoe UI', Roboto, sans-serif !important;
                    -webkit-font-smoothing: antialiased;
                }

                main, [role="main"], .main-content, .chat-window, .infinite-scroller, .chat-history, .conversation-container {
                    box-sizing: border-box !important;
                }
            `;
            document.head.appendChild(style);
        })();
        """
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    }

    /// Genera el script que inyecta la sección interactiva "Carpetas conectadas" en la barra lateral de Gemini Web.
    private static func createSparkFolderBridgeScript() -> WKUserScript {
        let source = """
        (function() {
            'use strict';
            if (window.location.hostname.includes('accounts.google.com')) return;

            let connectedFoldersData = [];

            window.__updateConnectedFolders = function(folders) {
                connectedFoldersData = Array.isArray(folders) ? folders : [];
                renderFolders();
            };

            function isSparkMode() {
                const text = document.body ? document.body.innerText : '';
                const hasSparkKeywords = text.includes('Tareas') || 
                                         text.includes('Personalizar') || 
                                         text.includes('Habilidades') || 
                                         text.includes('Programaciones') || 
                                         text.includes('Actividades programadas') ||
                                         text.includes('Aplicaciones conectadas') ||
                                         text.includes('Apps conectadas');
                return hasSparkKeywords;
            }

            function findSidebarInsertionTarget() {
                const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
                let textNode;
                const matches = [];

                while (textNode = walker.nextNode()) {
                    const val = textNode.nodeValue.trim();
                    if (val === 'Aplicaciones conectadas' || 
                        val === 'Apps conectadas' || 
                        val === 'Habilidades' || 
                        val === 'Actividades programadas' || 
                        val === 'Programaciones') {
                        matches.push(textNode.parentElement);
                    }
                }

                for (const el of matches) {
                    const row = el.closest('a, button, [role="listitem"], mat-list-item, li, div') || el;
                    const rect = row.getBoundingClientRect();
                    if (rect.left < 400 && rect.width > 0 && rect.width < 450 && rect.top > 0) {
                        return {
                            parent: row.parentElement,
                            referenceNode: row.nextSibling
                        };
                    }
                }

                const sidebars = document.querySelectorAll('bard-sidenav, side-navigation-v2, side-navigation, [role="navigation"], aside, .side-nav');
                for (const sb of sidebars) {
                    const rect = sb.getBoundingClientRect();
                    if (rect.left < 50 && rect.width > 150 && rect.width < 450) {
                        const targetContainer = sb.querySelector('.scrollable-container, .middle-section, mat-nav-list, ul') || sb;
                        return {
                            parent: targetContainer,
                            referenceNode: null
                        };
                    }
                }

                return null;
            }

            function renderFolders() {
                const listContainer = document.getElementById('gemini-mac-folders-list');
                if (!listContainer) return;

                if (connectedFoldersData.length === 0) {
                    listContainer.innerHTML = '';
                    return;
                }

                let html = '';
                connectedFoldersData.forEach(folder => {
                    html += `
                    <div class="gemini-mac-folder-item" data-id="${folder.id}" title="${folder.path}">
                        <div class="folder-info">
                            <span class="folder-icon">📁</span>
                            <div class="folder-text">
                                <div class="folder-name">${folder.name}</div>
                                <div class="folder-count">${folder.fileCount} archivos</div>
                            </div>
                        </div>
                        <div class="folder-actions">
                            <button class="folder-action-btn folder-insert-btn" title="Adjuntar contexto al prompt" data-id="${folder.id}">➕</button>
                            <button class="folder-action-btn folder-delete-btn" title="Eliminar de carpetas conectadas" data-id="${folder.id}">✕</button>
                        </div>
                    </div>`;
                });
                listContainer.innerHTML = html;

                listContainer.querySelectorAll('.gemini-mac-folder-item').forEach(item => {
                    const folderId = item.getAttribute('data-id');
                    item.addEventListener('click', function(e) {
                        if (e.target.closest('.folder-action-btn')) return;
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(sparkFolderHandler)) {
                            window.webkit.messageHandlers.\(sparkFolderHandler).postMessage({ action: 'attachFolderContext', id: folderId });
                        }
                    });
                });

                listContainer.querySelectorAll('.folder-delete-btn').forEach(btn => {
                    btn.addEventListener('click', function(e) {
                        e.stopPropagation();
                        const folderId = this.getAttribute('data-id');
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(sparkFolderHandler)) {
                            window.webkit.messageHandlers.\(sparkFolderHandler).postMessage({ action: 'removeFolder', id: folderId });
                        }
                    });
                });

                listContainer.querySelectorAll('.folder-insert-btn').forEach(btn => {
                    btn.addEventListener('click', function(e) {
                        e.stopPropagation();
                        const folderId = this.getAttribute('data-id');
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(sparkFolderHandler)) {
                            window.webkit.messageHandlers.\(sparkFolderHandler).postMessage({ action: 'attachFolderContext', id: folderId });
                        }
                    });
                });
            }

            function injectConnectedFoldersUI() {
                const existing = document.getElementById('gemini-mac-folders-section');

                if (!isSparkMode()) {
                    if (existing) existing.style.display = 'none';
                    return;
                }

                if (existing) {
                    existing.style.display = 'block';
                    const rect = existing.getBoundingClientRect();
                    if (rect.left < 400 && rect.width < 450) {
                        return;
                    } else {
                        existing.remove();
                    }
                }

                const target = findSidebarInsertionTarget();
                if (!target || !target.parent) return;

                const section = document.createElement('div');
                section.id = 'gemini-mac-folders-section';
                section.className = 'gemini-mac-folders-section';
                section.innerHTML = `
                    <div class="gemini-mac-folders-title">Carpetas conectadas</div>
                    <button id="gemini-add-mac-folder-btn" class="gemini-add-mac-folder-btn" type="button">
                        <span class="plus-icon">+</span>
                        <span>Agregar carpeta de Mac</span>
                    </button>
                    <div id="gemini-mac-folders-list" class="gemini-mac-folders-list"></div>
                `;

                if (target.referenceNode) {
                    target.parent.insertBefore(section, target.referenceNode);
                } else {
                    target.parent.appendChild(section);
                }

                const addBtn = document.getElementById('gemini-add-mac-folder-btn');
                if (addBtn) {
                    addBtn.addEventListener('click', function(e) {
                        e.preventDefault();
                        e.stopPropagation();
                        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(sparkFolderHandler)) {
                            window.webkit.messageHandlers.\(sparkFolderHandler).postMessage({ action: 'addFolder' });
                        }
                    });
                }

                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(sparkFolderHandler)) {
                    window.webkit.messageHandlers.\(sparkFolderHandler).postMessage({ action: 'getConnectedFolders' });
                }

                renderFolders();
            }

            const style = document.createElement('style');
            style.textContent = `
                .gemini-mac-folders-section {
                    margin-top: 14px;
                    margin-bottom: 16px;
                    padding: 0 8px;
                    box-sizing: border-box;
                    width: 100%;
                    max-width: 280px;
                }
                .gemini-mac-folders-title {
                    font-size: 12px;
                    font-weight: 500;
                    color: #c4c7c5;
                    padding: 4px 12px 6px 12px;
                    letter-spacing: 0.2px;
                    user-select: none;
                }
                .gemini-add-mac-folder-btn {
                    display: flex;
                    align-items: center;
                    width: calc(100% - 16px);
                    height: 36px;
                    margin: 2px 8px;
                    padding: 0 14px;
                    background: rgba(255, 255, 255, 0.05);
                    border: 1px solid rgba(255, 255, 255, 0.08);
                    border-radius: 18px;
                    color: #e3e3e3;
                    font-size: 13px;
                    font-weight: 500;
                    cursor: pointer;
                    transition: all 0.15s ease;
                    box-sizing: border-box;
                    outline: none;
                    text-align: left;
                }
                .gemini-add-mac-folder-btn:hover {
                    background: rgba(255, 255, 255, 0.12);
                    color: #ffffff;
                    border-color: rgba(255, 255, 255, 0.18);
                    transform: translateY(-1px);
                }
                .gemini-add-mac-folder-btn .plus-icon {
                    font-size: 16px;
                    margin-right: 8px;
                    font-weight: 400;
                    color: #a8c7fa;
                }
                .gemini-mac-folders-list {
                    margin-top: 8px;
                    display: flex;
                    flex-direction: column;
                    gap: 4px;
                    padding: 0 4px;
                }
                .gemini-mac-folder-item {
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    padding: 6px 10px;
                    margin: 0 4px;
                    background: rgba(255, 255, 255, 0.03);
                    border: 1px solid rgba(255, 255, 255, 0.05);
                    border-radius: 10px;
                    cursor: pointer;
                    transition: all 0.15s ease;
                }
                .gemini-mac-folder-item:hover {
                    background: rgba(255, 255, 255, 0.08);
                    border-color: rgba(255, 255, 255, 0.12);
                }
                .gemini-mac-folder-item .folder-info {
                    display: flex;
                    align-items: center;
                    gap: 8px;
                    overflow: hidden;
                }
                .gemini-mac-folder-item .folder-icon {
                    font-size: 15px;
                }
                .gemini-mac-folder-item .folder-text {
                    display: flex;
                    flex-direction: column;
                    overflow: hidden;
                }
                .gemini-mac-folder-item .folder-name {
                    font-size: 12px;
                    font-weight: 500;
                    color: #e3e3e3;
                    white-space: nowrap;
                    overflow: hidden;
                    text-overflow: ellipsis;
                    max-width: 140px;
                }
                .gemini-mac-folder-item .folder-count {
                    font-size: 10px;
                    color: #8e918f;
                }
                .gemini-mac-folder-item .folder-actions {
                    display: flex;
                    align-items: center;
                    gap: 2px;
                    opacity: 0.5;
                    transition: opacity 0.15s ease;
                }
                .gemini-mac-folder-item:hover .folder-actions {
                    opacity: 1;
                }
                .folder-action-btn {
                    background: transparent;
                    border: none;
                    color: #c4c7c5;
                    cursor: pointer;
                    padding: 3px 5px;
                    border-radius: 4px;
                    font-size: 11px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                .folder-action-btn:hover {
                    background: rgba(255, 255, 255, 0.15);
                    color: #ffffff;
                }
            `;
            document.head.appendChild(style);

            const observer = new MutationObserver(function() {
                injectConnectedFoldersUI();
            });

            observer.observe(document.body, { childList: true, subtree: true });

            setTimeout(injectConnectedFoldersUI, 500);
            setTimeout(injectConnectedFoldersUI, 1200);
            setTimeout(injectConnectedFoldersUI, 2500);
        })();
        """
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    }

    /// Código fuente JS para canalizar registros de consola hacia la salida estándar en depuración.
    private static let consoleLogBridgeSource = """
    (function() {
        if (window.location.hostname.includes('accounts.google.com')) return;
        const originalLog = console.log;
        console.log = function(...args) {
            originalLog.apply(console, args);
            try {
                const message = args.map(arg => {
                    if (typeof arg === 'object') {
                        return JSON.stringify(arg, null, 2);
                    }
                    return String(arg);
                }).join(' ');
                window.webkit.messageHandlers.\(consoleLogHandler).postMessage(message);
            } catch (e) {}
        };
    })();
    """

    /// Código fuente JS que gestiona el amortiguamiento de eventos Enter durante la composición de teclado IME.
    private static let imeFixSource = """
    (function() {
        'use strict';
        if (window.location.hostname.includes('accounts.google.com')) return;

        let imeActive = false;
        let imeEverUsed = false;
        let compositionEndTime = 0;
        const BUFFER_TIME = 300;

        function isInIMEWindow() {
            return imeActive || (Date.now() - compositionEndTime < BUFFER_TIME);
        }

        document.addEventListener('compositionstart', function() {
            imeActive = true;
            imeEverUsed = true;
        }, true);

        document.addEventListener('compositionend', function() {
            imeActive = false;
            compositionEndTime = Date.now();
        }, true);

        document.addEventListener('keydown', function(e) {
            if (!imeEverUsed) return;
            if (e.key !== 'Enter' || e.shiftKey || e.ctrlKey || e.altKey) return;

            if (isInIMEWindow() || e.isComposing || e.keyCode === 229) {
                e.stopImmediatePropagation();
                e.preventDefault();
            }
        }, true);

        document.addEventListener('beforeinput', function(e) {
            if (!imeEverUsed) return;
            if (e.inputType !== 'insertParagraph' && e.inputType !== 'insertLineBreak') return;

            if (isInIMEWindow()) {
                e.stopImmediatePropagation();
                e.preventDefault();
            }
        }, true);
    })();
    """
}
