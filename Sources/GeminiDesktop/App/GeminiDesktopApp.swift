//
//  GeminiDesktopApp.swift
//  GeminiDesktop
//
//  Autor: aagrandaz@gmail.com
//

import SwiftUI
import AppKit
import GeminiCore
import GeminiWebBridge
import GeminiAppKit
import GeminiUI

private typealias ViewState<Value> = SwiftUI.State<Value>

/// Punto de entrada principal (`@main`) de la aplicación Gemini Desktop para macOS.
/// Inicializa el contenedor de dependencias, define las escenas (`Window`, `Settings`, `MenuBarExtra`) y los comandos de menú.
@main
struct GeminiDesktopApp: App {
    /// Adaptador del delegado de aplicación nativo AppKit.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    /// Contenedor de inversión de control que mantiene vivas las dependencias centrales.
    @ViewState private var container: DependencyContainer

    /// Inicializador principal de la estructura de la aplicación.
    init() {
        let env = DependencyContainer()
        self._container = ViewState(initialValue: env)
        env.preferences.appTheme.apply()
    }

    /// Definición declarativa de las escenas de SwiftUI.
    var body: some Scene {
        let coordinator = container.coordinator
        let webViewModel = container.webViewModel
        let preferences = container.preferences
        let eventBus = container.eventBus

        // Ventana Principal
        Window(WindowManager.Constants.mainWindowTitle, id: Constants.mainWindowID) {
            MainWindowView(
                webViewModel: webViewModel,
                eventBus: eventBus,
                onRegisterOpenWindow: { action in
                    coordinator.registerOpenWindowAction(action)
                }
            )
            .frame(minWidth: Constants.mainWindowMinWidth, minHeight: Constants.mainWindowMinHeight)
            .onAppear {
                appDelegate.preferences = preferences
                appDelegate.eventBus = eventBus
            }
        }
        .defaultSize(width: Constants.mainWindowDefaultWidth, height: Constants.mainWindowDefaultHeight)
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Archivo Menu
            CommandGroup(replacing: .newItem) {
                Button("Nuevo chat") {
                    webViewModel.openNewChat()
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Nuevo chat temporal") {
                    webViewModel.loadURL("https://gemini.google.com/app?temporary=true")
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

                Button("Modelo siguiente") {}
                    .keyboardShortcut("}", modifiers: [.command, .shift])

                Button("Modelo anterior") {}
                    .keyboardShortcut("{", modifiers: [.command, .shift])
            }

            // Visualización Menu
            CommandGroup(after: .toolbar) {
                Button("Activar o desactivar la barra lateral") {
                    eventBus.send(.toggleSidebar)
                }
                .keyboardShortcut("s", modifiers: [.command, .control])

                Button("Activar o desactivar el chat pequeño") {
                    coordinator.toggleChatBar()
                }

                Button("Volver a cargar") {
                    webViewModel.reload()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Aumentar el tamaño del texto") {
                    webViewModel.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Cambiar texto al tamaño normal") {
                    webViewModel.resetZoom()
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("Reducir el tamaño del texto") {
                    webViewModel.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)

                Divider()

                Button("Página anterior") {
                    webViewModel.goBack()
                }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!webViewModel.canGoBack)

                Button("Página siguiente") {
                    webViewModel.goForward()
                }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!webViewModel.canGoForward)

                Divider()

                Button(coordinator.alwaysOnTop ? "Desactivar Siempre al Frente" : "Mantener Siempre al Frente") {
                    coordinator.toggleAlwaysOnTop()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }

            // Chats Menu
            CommandMenu("Chats") {
                Section("Recientes") {
                    Button("Anteproyecto: Microservicio PLN") {
                        webViewModel.loadURL("https://gemini.google.com/app")
                    }
                    .keyboardShortcut("1", modifiers: .command)

                    Button("Diseño y Planos Mueble TV") {
                        webViewModel.loadURL("https://gemini.google.com/app")
                    }
                    .keyboardShortcut("2", modifiers: .command)
                }

                Divider()

                Button("Ver todos los chats") {
                    webViewModel.loadURL("https://gemini.google.com/app")
                }

                Button("Buscar...") {}
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

        // Ventana de Ajustes / Preferencias
        Settings {
            SettingsView(preferences: preferences, webViewModel: webViewModel)
        }
        .defaultSize(width: Constants.settingsWindowDefaultWidth, height: Constants.settingsWindowDefaultHeight)

        // Elemento de la Barra de Menús del Sistema
        MenuBarExtra {
            MenuBarView(
                preferences: preferences,
                webViewModel: webViewModel,
                onOpenMainWindow: { coordinator.openMainWindow() },
                onToggleChatBar: { coordinator.toggleChatBar() },
                onToggleAlwaysOnTop: { coordinator.toggleAlwaysOnTop() },
                onRegisterOpenWindow: { action in
                    coordinator.registerOpenWindowAction(action)
                }
            )
        } label: {
            Image(systemName: Constants.menuBarIcon)
                .onAppear {
                    appDelegate.preferences = preferences
                    appDelegate.eventBus = eventBus
                    coordinator.configureLaunchPolicy()
                }
        }
        .menuBarExtraStyle(.menu)
    }
}

extension GeminiDesktopApp {
    /// Constantes de diseño y dimensiones de ventanas.
    struct Constants {
        /// Ancho mínimo de la ventana principal.
        static let mainWindowMinWidth: CGFloat = 800
        /// Alto mínimo de la ventana principal.
        static let mainWindowMinHeight: CGFloat = 550
        /// Ancho por defecto de la ventana principal.
        static let mainWindowDefaultWidth: CGFloat = 1100
        /// Alto por defecto de la ventana principal.
        static let mainWindowDefaultHeight: CGFloat = 750

        /// Ancho por defecto de la ventana de ajustes.
        static let settingsWindowDefaultWidth: CGFloat = 720
        /// Alto por defecto de la ventana de ajustes.
        static let settingsWindowDefaultHeight: CGFloat = 480

        /// Identificador de escena para la ventana principal.
        static let mainWindowID = "main"
        /// Nombre del ícono SF Symbol en la barra de menús.
        static let menuBarIcon = "sparkle"
    }
}
