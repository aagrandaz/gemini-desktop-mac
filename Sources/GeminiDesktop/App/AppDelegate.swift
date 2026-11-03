//
//  AppDelegate.swift
//  GeminiDesktop
//
//  Autor: aagrandaz@gmail.com
//

import AppKit
import GeminiCore

/// Delegado de ciclo de vida de la aplicación macOS (`NSApplicationDelegate`).
/// Gestiona la política de activación, reapertura desde el Dock y eventos iniciales del sistema.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Repositorio de preferencias inyectado desde la jerarquía de SwiftUI.
    var preferences: PreferencesStoring?
    /// Bus de eventos inyectado para despachar solicitudes de apertura de ventana.
    var eventBus: AppEventStreaming?

    /// Invocado cuando la aplicación finaliza su proceso de arranque.
    /// Configura la visibilidad en el Dock y determina si se muestra la ventana principal.
    func applicationDidFinishLaunching(_ notification: Notification) {
        let hideDockIcon = preferences?.hideDockIcon ?? false
        let hideWindowAtLaunch = preferences?.hideWindowAtLaunch ?? false

        if hideDockIcon {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }

        if !hideWindowAtLaunch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                NSApp.activate(ignoringOtherApps: true)
                self?.eventBus?.send(.openMainWindow)
            }
        }
    }

    /// Invocado cuando el usuario hace clic en el ícono del Dock estando la app abierta sin ventanas visibles.
    /// Trae al frente la ventana principal.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        eventBus?.send(.openMainWindow)
        return true
    }
}
