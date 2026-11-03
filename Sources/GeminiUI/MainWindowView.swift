//
//  MainWindowView.swift
//  GeminiUI
//
//  Autor: aagrandaz@gmail.com
//

import SwiftUI
import AppKit
import GeminiCore
import GeminiWebBridge
import GeminiAppKit

/// Vista raíz de la ventana principal de la aplicación.
/// Integra la instancia compartida de `WKWebView`, barra superior transparente de arrastre e indicador lineal de progreso.
public struct MainWindowView: View {
    /// Modelo de estado de navegación y WebKit.
    public let webViewModel: WebViewModel
    /// Bus de eventos para suscribirse a acciones reactivas de apertura y ajuste.
    public let eventBus: AppEventStreaming
    /// Clausura para registrar la acción `OpenWindowAction` con el coordinador.
    public let onRegisterOpenWindow: (@escaping (String) -> Void) -> Void

    /// Inyección de entorno para invocar apertura de ventanas en SwiftUI.
    @Environment(\.openWindow) private var openWindow

    /// Inicializador de la vista principal.
    /// - Parameters:
    ///   - webViewModel: Modelo de vista web observable.
    ///   - eventBus: Bus de eventos de la app.
    ///   - onRegisterOpenWindow: Clausura que registra la apertura de ventanas secundarias.
    public init(
        webViewModel: WebViewModel,
        eventBus: AppEventStreaming,
        onRegisterOpenWindow: @escaping (@escaping (String) -> Void) -> Void
    ) {
        self.webViewModel = webViewModel
        self.eventBus = eventBus
        self.onRegisterOpenWindow = onRegisterOpenWindow
    }

    public var body: some View {
        ZStack(alignment: .top) {
            GeminiWebView(webView: webViewModel.wkWebView)
                .padding(.top, 28)
                .ignoresSafeArea(.all, edges: [.horizontal, .bottom])

            WindowDragView()
                .frame(height: 28)
                .frame(maxWidth: .infinity)

            if webViewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(Color.accentColor)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: webViewModel.isLoading)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        .onAppear {
            onRegisterOpenWindow { id in
                openWindow(id: id)
            }
        }
        .task {
            for await event in eventBus.stream() {
                if event == .openSettings {
                    openWindow(id: "settings")
                }
            }
        }
    }
}
