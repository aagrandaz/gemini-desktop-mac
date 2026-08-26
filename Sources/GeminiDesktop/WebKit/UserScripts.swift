//
//  UserScripts.swift
//  GeminiDesktop
//
//  Created by alexcding on 2025-12-15.
//

import WebKit

/// Collection of user scripts injected into WKWebView
enum UserScripts {

    /// Message handler names for WebKit bridging
    static let consoleLogHandler = "consoleLog"
    static let sparkFolderHandler = "sparkFolderHandler"

    /// Creates all user scripts to be injected into the WebView
    static func createAllScripts() -> [WKUserScript] {
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

    /// Creates a script that bridges console.log to native Swift
    private static func createConsoleLogBridgeScript() -> WKUserScript {
        WKUserScript(
            source: consoleLogBridgeSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }

    /// Creates the IME fix script that resolves the double-enter issue
    private static func createIMEFixScript() -> WKUserScript {
        WKUserScript(
            source: imeFixSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    }

    /// Injects CSS and JS for native macOS traffic lights and draggable titlebar area
    private static func createWindowDragScript() -> WKUserScript {
        let source = """
        (function() {
            if (window.location.hostname.includes('accounts.google.com')) return;

            const style = document.createElement('style');
            style.textContent = `
                /* Allow dragging from top navigation bar */
                header, nav[role="navigation"], .app-header {
                    -webkit-app-region: drag;
                    user-select: none;
                }
                /* Interactive elements in header remain clickable */
                header button, header a, header input, nav button, nav a {
                    -webkit-app-region: no-drag;
                }
                /* Adjust font smoothing */
                body {
                    -webkit-font-smoothing: antialiased;
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

    /// Injects the Spark connected folders UI and native macOS folder picker bridge
    private static func createSparkFolderBridgeScript() -> WKUserScript {
        let source = """
        (function() {
            'use strict';
            if (window.location.hostname.includes('accounts.google.com')) return;

            let connectedFoldersData = [];

            // Global update function called by native Swift
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

            function findSidebarInsertionPoint() {
                // Find container with Personalizar / Habilidades / Apps conectadas
                const candidates = document.querySelectorAll('nav, [role="navigation"], .side-nav, .mat-drawer-inner-container, bard-sidenav, .sidebar, [class*="side-nav"], [class*="sidebar"]');
                for (const nav of candidates) {
                    if (nav.innerText.includes('Personalizar') || nav.innerText.includes('Habilidades') || nav.innerText.includes('Apps conectadas') || nav.innerText.includes('Aplicaciones conectadas') || nav.innerText.includes('Tareas')) {
                        return nav;
                    }
                }
                // Fallback: Find parent of element containing 'Aplicaciones conectadas' or 'Apps conectadas'
                const allElements = document.querySelectorAll('div, section, mat-nav-list, ul');
                for (const el of allElements) {
                    if ((el.innerText.includes('Apps conectadas') || el.innerText.includes('Aplicaciones conectadas')) && el.children.length >= 1) {
                        return el.parentElement || el;
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
                            <button class="folder-action-btn folder-insert-btn" title="Adjuntar contexto de carpeta" data-id="${folder.id}">➕</button>
                            <button class="folder-action-btn folder-delete-btn" title="Eliminar de carpetas conectadas" data-id="${folder.id}">✕</button>
                        </div>
                    </div>`;
                });
                listContainer.innerHTML = html;

                // Event Listeners for items
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
                if (!isSparkMode()) {
                    const existing = document.getElementById('gemini-mac-folders-section');
                    if (existing) existing.style.display = 'none';
                    return;
                }

                let existing = document.getElementById('gemini-mac-folders-section');
                if (existing) {
                    existing.style.display = 'block';
                    return;
                }

                const nav = findSidebarInsertionPoint();
                if (!nav) return;

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

                nav.appendChild(section);

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

                // Request current folders from Swift
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(sparkFolderHandler)) {
                    window.webkit.messageHandlers.\(sparkFolderHandler).postMessage({ action: 'getConnectedFolders' });
                }

                renderFolders();
            }

            // Styles
            const style = document.createElement('style');
            style.textContent = `
                .gemini-mac-folders-section {
                    margin-top: 16px;
                    margin-bottom: 20px;
                    padding: 0 12px;
                    font-family: 'Google Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                }
                .gemini-mac-folders-title {
                    font-size: 13px;
                    font-weight: 500;
                    color: #c4c7c5;
                    padding: 4px 8px 8px 8px;
                    letter-spacing: 0.2px;
                }
                .gemini-add-mac-folder-btn {
                    display: flex;
                    align-items: center;
                    width: 100%;
                    height: 38px;
                    padding: 0 16px;
                    background: rgba(255, 255, 255, 0.06);
                    border: 1px solid rgba(255, 255, 255, 0.08);
                    border-radius: 19px;
                    color: #e3e3e3;
                    font-size: 13px;
                    font-weight: 500;
                    cursor: pointer;
                    transition: all 0.15s ease-in-out;
                    box-sizing: border-box;
                    outline: none;
                }
                .gemini-add-mac-folder-btn:hover {
                    background: rgba(255, 255, 255, 0.12);
                    color: #ffffff;
                    border-color: rgba(255, 255, 255, 0.2);
                    transform: translateY(-1px);
                }
                .gemini-add-mac-folder-btn .plus-icon {
                    font-size: 17px;
                    margin-right: 8px;
                    font-weight: 400;
                    color: #a8c7fa;
                }
                .gemini-mac-folders-list {
                    margin-top: 10px;
                    display: flex;
                    flex-direction: column;
                    gap: 6px;
                }
                .gemini-mac-folder-item {
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    padding: 8px 12px;
                    background: rgba(255, 255, 255, 0.03);
                    border: 1px solid rgba(255, 255, 255, 0.05);
                    border-radius: 12px;
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
                    gap: 10px;
                    overflow: hidden;
                }
                .gemini-mac-folder-item .folder-icon {
                    font-size: 16px;
                }
                .gemini-mac-folder-item .folder-text {
                    display: flex;
                    flex-direction: column;
                    overflow: hidden;
                }
                .gemini-mac-folder-item .folder-name {
                    font-size: 13px;
                    font-weight: 500;
                    color: #e3e3e3;
                    white-space: nowrap;
                    overflow: hidden;
                    text-overflow: ellipsis;
                }
                .gemini-mac-folder-item .folder-count {
                    font-size: 11px;
                    color: #8e918f;
                }
                .gemini-mac-folder-item .folder-actions {
                    display: flex;
                    align-items: center;
                    gap: 4px;
                    opacity: 0.6;
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
                    padding: 4px;
                    border-radius: 6px;
                    font-size: 12px;
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

            // Continuous observation of DOM changes
            const observer = new MutationObserver(function() {
                injectConnectedFoldersUI();
            });

            observer.observe(document.body, { childList: true, subtree: true });

            setTimeout(injectConnectedFoldersUI, 500);
            setTimeout(injectConnectedFoldersUI, 1500);
            setTimeout(injectConnectedFoldersUI, 3000);
        })();
        """
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
    }

    // MARK: - Script Sources

    /// JavaScript to bridge console.log to native Swift via WKScriptMessageHandler
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

    /// JavaScript to fix IME Enter issue on Gemini
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
