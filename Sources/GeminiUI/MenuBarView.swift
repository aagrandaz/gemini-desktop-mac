//
//  MenuBarView.swift
//  GeminiUI
//
//  Autor: aagrandaz@gmail.com
//

import SwiftUI
import AppKit
import GeminiCore
import GeminiWebBridge

/// Menú desplegable para el ícono de estado de la barra de menús del sistema macOS (`MenuBarExtra`).
/// Ofrece accesos rápidos a la ventana principal, barra de chat, nuevo prompt y ajustes.
public struct MenuBarView: View {
    /// Repositorio reactivo de configuración.
    public let preferences: PreferencesRepository
    /// Modelo de navegación web.
    public let webViewModel: WebViewModel
    /// Acción para abrir y enfocar la ventana principal.
    public let onOpenMainWindow: () -> Void
    /// Acción para alternar la visibilidad de la barra de chat.
    public let onToggleChatBar: () -> Void
    /// Acción para alternar la flotabilidad de la ventana principal.
    public let onToggleAlwaysOnTop: () -> Void
    /// Clausura para registrar la acción de apertura de ventanas con el coordinador.
    public let onRegisterOpenWindow: (@escaping (String) -> Void) -> Void

    @Environment(\.openWindow) private var openWindow

    /// Inicializador de la vista del menú de estado.
    public init(
        preferences: PreferencesRepository,
        webViewModel: WebViewModel,
        onOpenMainWindow: @escaping () -> Void,
        onToggleChatBar: @escaping () -> Void,
        onToggleAlwaysOnTop: @escaping () -> Void,
        onRegisterOpenWindow: @escaping (@escaping (String) -> Void) -> Void
    ) {
        self.preferences = preferences
        self.webViewModel = webViewModel
        self.onOpenMainWindow = onOpenMainWindow
        self.onToggleChatBar = onToggleChatBar
        self.onToggleAlwaysOnTop = onToggleAlwaysOnTop
        self.onRegisterOpenWindow = onRegisterOpenWindow
    }

    public var body: some View {
        Group {
            Button {
                onOpenMainWindow()
            } label: {
                Label("Abrir Gemini Desktop", systemImage: "macwindow")
            }
            .keyboardShortcut("o", modifiers: .command)

            Button {
                onToggleChatBar()
            } label: {
                Label("Barra Flotante de Prompt", systemImage: "rectangle.bottomthird.inset.filled")
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Button {
                webViewModel.openNewChat()
            } label: {
                Label("Nuevo Chat", systemImage: "plus.bubble")
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button {
                webViewModel.reload()
            } label: {
                Label("Recargar Página", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)

            Button {
                onToggleAlwaysOnTop()
            } label: {
                if preferences.alwaysOnTop {
                    Label("Siempre al Frente ✓", systemImage: "pin.fill")
                } else {
                    Label("Mantener Siempre al Frente", systemImage: "pin")
                }
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])

            Divider()

            SettingsLink {
                Label("Ajustes...", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Salir de Gemini Desktop", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .onAppear {
            onRegisterOpenWindow { id in
                openWindow(id: id)
            }
        }
    }
}
