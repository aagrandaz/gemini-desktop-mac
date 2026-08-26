//
//  GeminiDesktopApp.swift
//  GeminiDesktop
//
//  Created by alexcding on 2025-12-13.
//

import SwiftUI
import AppKit
import Combine

// MARK: - Main App
@main
struct GeminiDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var coordinator = AppCoordinator()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window(AppCoordinator.Constants.mainWindowTitle, id: Constants.mainWindowID) {
            MainWindowView(coordinator: $coordinator)
                .frame(minWidth: Constants.mainWindowMinWidth, minHeight: Constants.mainWindowMinHeight)
        }
        .defaultSize(width: Constants.mainWindowDefaultWidth, height: Constants.mainWindowDefaultHeight)
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Archivo Menu
            CommandGroup(replacing: .newItem) {
                Button("Nuevo chat") {
                    coordinator.openNewChat()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Nuevo chat temporal") {
                    coordinator.loadURL("https://gemini.google.com/app?temporary=true")
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Divider()

                Button("Abrir chat pequeño") {
                    coordinator.showChatBar()
                }

                Button("Abrir app") {
                    coordinator.bringMainWindowToFront()
                }
            }

            // Edición Menu
            CommandGroup(after: .pasteboard) {
                Divider()

                Button("Modelo siguiente") {
                    // Quick model switcher
                }
                .keyboardShortcut("}", modifiers: [.command, .shift])

                Button("Modelo anterior") {
                    // Quick model switcher
                }
                .keyboardShortcut("{", modifiers: [.command, .shift])
            }

            // Visualización Menu
            CommandGroup(after: .toolbar) {
                Button("Activar o desactivar la barra lateral") {
                    NotificationCenter.default.post(name: .init("ToggleSidebar"), object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .control])

                Button("Activar o desactivar el chat pequeño") {
                    coordinator.toggleChatBar()
                }

                Button("Volver a cargar") {
                    coordinator.reload()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Aumentar el tamaño del texto") {
                    coordinator.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Cambiar texto al tamaño normal") {
                    coordinator.resetZoom()
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("Reducir el tamaño del texto") {
                    coordinator.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)

                Divider()

                Button("Página anterior") {
                    coordinator.goBack()
                }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!coordinator.canGoBack)

                Button("Página siguiente") {
                    coordinator.goForward()
                }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!coordinator.canGoForward)

                Divider()

                Button(coordinator.alwaysOnTop ? "Desactivar Siempre al Frente" : "Mantener Siempre al Frente") {
                    coordinator.toggleAlwaysOnTop()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }

            // Custom Chats Menu
            CommandMenu("Chats") {
                Section("Recientes") {
                    Button("Anteproyecto: Microservicio PLN") {
                        coordinator.loadURL("https://gemini.google.com/app")
                    }
                    .keyboardShortcut("1", modifiers: .command)

                    Button("Diseño y Planos Mueble TV") {
                        coordinator.loadURL("https://gemini.google.com/app")
                    }
                    .keyboardShortcut("2", modifiers: .command)
                }

                Divider()

                Button("Ver todos los chats") {
                    coordinator.loadURL("https://gemini.google.com/app")
                }

                Button("Buscar...") {
                    // Search in chats
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            // Ayuda Menu
            CommandGroup(replacing: .help) {
                Button("Ayuda de Gemini") {
                    if let url = URL(string: "https://support.google.com/gemini") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("Enviar comentarios") {
                    if let url = URL(string: "https://gemini.google.com/feedback") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Divider()

                Button("Política de Privacidad") {
                    if let url = URL(string: "https://policies.google.com/privacy") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("Condiciones del Servicio") {
                    if let url = URL(string: "https://policies.google.com/terms") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        Settings {
            SettingsView(coordinator: $coordinator)
        }
        .defaultSize(width: Constants.settingsWindowDefaultWidth, height: Constants.settingsWindowDefaultHeight)

        MenuBarExtra {
            MenuBarView(coordinator: $coordinator)
        } label: {
            Image(systemName: Constants.menuBarIcon)
                .onAppear {
                    let hideWindowAtLaunch = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hideWindowAtLaunch.rawValue)
                    let hideDockIcon = UserDefaults.standard.bool(forKey: UserDefaultsKeys.hideDockIcon.rawValue)

                    if hideDockIcon || hideWindowAtLaunch {
                        NSApp.setActivationPolicy(.accessory)
                        if hideWindowAtLaunch {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Constants.hideWindowDelay) {
                                for window in NSApp.windows {
                                    if window.identifier?.rawValue == Constants.mainWindowID || window.title == AppCoordinator.Constants.mainWindowTitle {
                                        window.orderOut(nil)
                                    }
                                }
                            }
                        }
                    } else {
                        NSApp.setActivationPolicy(.regular)
                    }
                }
        }
        .menuBarExtraStyle(.menu)
    }

    init() {
        // Apply saved theme on launch
        AppTheme.current.apply()

        let currentCoordinator = coordinator
        GlobalHotkeyManager.shared.registerDefaultShortcut {
            currentCoordinator.toggleChatBar()
        }
    }
}

// MARK: - Constants
extension GeminiDesktopApp {
    struct Constants {
        // Main Window
        static let mainWindowMinWidth: CGFloat = 800
        static let mainWindowMinHeight: CGFloat = 550
        static let mainWindowDefaultWidth: CGFloat = 1100
        static let mainWindowDefaultHeight: CGFloat = 750

        // Settings Window
        static let settingsWindowDefaultWidth: CGFloat = 720
        static let settingsWindowDefaultHeight: CGFloat = 480

        static let mainWindowID = "main"
        static let menuBarIcon = "sparkle"
        static let hideWindowDelay: TimeInterval = 0.1
    }
}
