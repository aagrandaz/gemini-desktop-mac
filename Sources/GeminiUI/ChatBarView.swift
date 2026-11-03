//
//  ChatBarView.swift
//  GeminiUI
//
//  Autor: aagrandaz@gmail.com
//

import SwiftUI
import WebKit
import AppKit
import GeminiAppKit

private typealias ViewState<Value> = SwiftUI.State<Value>

/// Vista de SwiftUI que presenta la barra flotante de prompt y chat rápido.
/// Embebe la instancia compartida de `WKWebView` y provee controles flotantes para arrastrar y maximizar.
public struct ChatBarView: View {
    /// Instancia de `WKWebView` compartida para renderizar la página de Gemini.
    public let webView: WKWebView
    /// Clausura ejecutada cuando el usuario pulsa el botón de maximizar a la ventana principal.
    public let onExpandToMain: () -> Void
    /// Estado local para efectos visuales de interacción con el botón de expandir.
    @ViewState private var isHoveringExpand = false

    /// Inicializador de la barra flotante de chat.
    /// - Parameters:
    ///   - webView: Instancia de `WKWebView` compartida.
    ///   - onExpandToMain: Acción de transición a la ventana principal.
    public init(webView: WKWebView, onExpandToMain: @escaping () -> Void) {
        self.webView = webView
        self.onExpandToMain = onExpandToMain
    }

    /// Calcula la compensación dinámica del botón de maximizar según la resolución de la pantalla.
    private var buttonOffset: CGSize {
        let screenHeight = NSScreen.main?.frame.height ?? 900
        let t = (screenHeight - 900) / 180
        let xOffset = -6.0 + t * 2.0
        let yOffset = -2.0 + t * 2.0
        return CGSize(width: xOffset, height: yOffset)
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            GeminiWebView(webView: webView)

            Button(action: onExpandToMain) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isHoveringExpand ? .primary : .secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(isHoveringExpand ? 0.25 : 0.1), radius: isHoveringExpand ? 6 : 3, x: 0, y: 2)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isHoveringExpand ? 0.4 : 0.15), lineWidth: 1)
                    )
                    .scaleEffect(isHoveringExpand ? 1.08 : 1.0)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { isHovering in
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    isHoveringExpand = isHovering
                }
            }
            .padding(16)
            .offset(buttonOffset)
            .help("Maximizar a Ventana Principal")

            VStack {
                HStack {
                    Spacer()
                        .frame(width: Constants.dragRegionLeading)
                    WindowDragView()
                        .frame(maxWidth: .infinity, maxHeight: Constants.dragRegionHeight)
                    Spacer()
                        .frame(width: Constants.dragRegionTrailing)
                }
                .padding(.top, Constants.dragRegionTopPadding)
                Spacer()
            }
        }
    }

    private enum Constants {
        static let dragRegionLeading: CGFloat = 160
        static let dragRegionTrailing: CGFloat = 120
        static let dragRegionHeight: CGFloat = 38
        static let dragRegionTopPadding: CGFloat = 16
    }
}
