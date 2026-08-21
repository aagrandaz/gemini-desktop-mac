import SwiftUI
import AppKit

struct MainWindowView: View {
    @Binding var coordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ZStack(alignment: .top) {
            GeminiWebView(webView: coordinator.webViewModel.wkWebView)

            if coordinator.webViewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: coordinator.webViewModel.isLoading)
        .onAppear {
            coordinator.openWindowAction = { id in
                openWindow(id: id)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
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
                    coordinator.goHome()
                } label: {
                    Image(systemName: "house")
                }
                .help("Inicio de Gemini (⇧⌘H)")

                Button {
                    coordinator.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Recargar Página (⌘R)")
            }

            ToolbarItem(placement: .principal) {
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

