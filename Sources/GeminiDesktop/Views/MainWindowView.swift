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
            // WebKit container with native 28pt top safe-area padding for macOS traffic lights
            GeminiWebView(webView: coordinator.webViewModel.wkWebView)
                .padding(.top, 28)
                .ignoresSafeArea(.all, edges: [.horizontal, .bottom])

            // Native Titlebar Draggable Area (uses shared WindowDragView)
            WindowDragView()
                .frame(height: 28)
                .frame(maxWidth: .infinity)

            // Subtle loading indicator
            if coordinator.webViewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(Color.accentColor)
                    .frame(height: 2)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
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
