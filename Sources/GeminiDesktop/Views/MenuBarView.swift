import SwiftUI
import AppKit

struct MenuBarView: View {
    @Binding var coordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Button {
                coordinator.openMainWindow()
            } label: {
                Label("Abrir Gemini Desktop", systemImage: "macwindow")
            }
            .keyboardShortcut("o", modifiers: .command)

            Button {
                coordinator.toggleChatBar()
            } label: {
                Label("Barra Flotante de Prompt", systemImage: "rectangle.bottomthird.inset.filled")
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Button {
                coordinator.openNewChat()
            } label: {
                Label("Nuevo Chat", systemImage: "plus.bubble")
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            Button {
                coordinator.reload()
            } label: {
                Label("Recargar Página", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: .command)

            Button {
                coordinator.toggleAlwaysOnTop()
            } label: {
                if coordinator.alwaysOnTop {
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
            coordinator.openWindowAction = { id in
                openWindow(id: id)
            }
        }
    }
}

