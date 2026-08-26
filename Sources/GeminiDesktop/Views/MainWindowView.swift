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

    var body: some View {
        ZStack(alignment: .top) {
            // Full-screen native WebKit container (identical to official macOS Gemini app)
            GeminiWebView(webView: coordinator.webViewModel.wkWebView)
                .ignoresSafeArea(.all, edges: .all)

            // Subtle loading indicator at the top
            if coordinator.webViewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(Color.accentColor)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: coordinator.webViewModel.isLoading)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
        .onAppear {
            coordinator.openWindowAction = { id in
                openWindow(id: id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("OpenSettings"))) { _ in
            openWindow(id: "settings")
        }
    }
}
