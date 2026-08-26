//
//  MainWindowView.swift
//  GeminiDesktop
//
//  Created on 2026-08-25.
//

import SwiftUI
import AppKit

struct MainWindowView: View {
    @Binding var coordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow
    @State private var sidebarMode: SidebarMode = .chat
    @State private var showSidebar: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            // Native Collapsible Sidebar
            if showSidebar {
                SparkSidebarView(
                    selectedMode: $sidebarMode,
                    onNewChat: {
                        sidebarMode = .chat
                        coordinator.openNewChat()
                    },
                    onSelectChat: { chatTitle in
                        sidebarMode = .chat
                        coordinator.loadURL("https://gemini.google.com/app")
                    },
                    onOpenSettingsCategory: { category in
                        openWindow(id: "settings")
                    }
                )
                .transition(.move(edge: .leading).combined(with: .opacity))

                Divider()
                    .background(Color.white.opacity(0.1))
            }

            // Main Content Area (Chat Webview vs Spark Canvas)
            ZStack(alignment: .top) {
                if sidebarMode == .spark {
                    SparkView(onSendToChat: { promptWithContext in
                        sidebarMode = .chat
                        coordinator.submitPrompt(promptWithContext)
                    })
                    .transition(.opacity)
                } else {
                    GeminiWebView(webView: coordinator.webViewModel.wkWebView)
                        .transition(.opacity)
                }

                if coordinator.webViewModel.isLoading && sidebarMode == .chat {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSidebar)
        .animation(.easeInOut(duration: 0.25), value: sidebarMode)
        .onAppear {
            coordinator.openWindowAction = { id in
                openWindow(id: id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ToggleSidebar"))) { _ in
            withAnimation {
                showSidebar.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("OpenSettings"))) { _ in
            openWindow(id: "settings")
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    withAnimation {
                        showSidebar.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help("Mostrar/Ocultar Barra Lateral (⌃⌘S)")

                Button {
                    coordinator.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .help("Página Anterior (⌘[)")
                .disabled(!coordinator.canGoBack)

                Button {
                    coordinator.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .help("Página Siguiente (⌘])")
                .disabled(!coordinator.canGoForward)

                Button {
                    coordinator.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Recargar Página (⌘R)")
            }

            ToolbarItem(placement: .principal) {
                if sidebarMode == .spark {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                        Text("Gemini Spark (BETA)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                } else {
                    Button {
                        coordinator.openNewChat()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.bubble")
                            Text("Nuevo Chat")
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Iniciar un nuevo chat (⌘N)")
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    coordinator.toggleAlwaysOnTop()
                } label: {
                    Image(systemName: coordinator.alwaysOnTop ? "pin.fill" : "pin")
                        .foregroundStyle(coordinator.alwaysOnTop ? Color.accentColor : Color.secondary)
                }
                .help(coordinator.alwaysOnTop ? "Desactivar Siempre al Frente" : "Mantener Siempre al Frente (⇧⌘T)")

                Button {
                    minimizeToPrompt()
                } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                }
                .help("Minimizar a Barra Flotante (⌘⇧G)")
            }
        }
    }

    private func minimizeToPrompt() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == AppCoordinator.Constants.mainWindowIdentifier || $0.title == AppCoordinator.Constants.mainWindowTitle }) {
            if !(window is NSPanel) {
                window.orderOut(nil)
            }
        }
        coordinator.showChatBar()
    }
}
