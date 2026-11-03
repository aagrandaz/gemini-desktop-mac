//
//  GlobalHotkeyManager.swift
//  GeminiAppKit
//
//  Autor: aagrandaz@gmail.com
//

import AppKit
import Carbon
import GeminiCore

/// Implementación desacoplada y sin singletons de `HotkeyManaging` que interactúa con la API Carbon de macOS.
/// Soporta modos aislados de desarrollo con atajos alternativos para evitar colisiones con instancias de producción.
public final class GlobalHotkeyManager: HotkeyManaging, @unchecked Sendable {
    /// Referencia de bajo nivel de Carbon al atajo de teclado registrado.
    private var hotKeyRef: EventHotKeyRef?
    /// Referencia al manejador de eventos del despachador de Carbon.
    private var eventHandler: EventHandlerRef?
    /// Indica si se está ejecutando en el entorno aislado de desarrollo.
    private let isIsolatedDevMode: Bool

    /// Clausura ejecutada cada vez que el atajo global es accionado por el usuario.
    public var onHotKeyTriggered: (() -> Void)?

    /// Inicializador del gestor de atajos globales.
    /// - Parameter isIsolatedDevMode: Si es verdadero, utiliza `⌘⌥⇧G` en lugar de `⌘⇧G`.
    public init(isIsolatedDevMode: Bool = false) {
        self.isIsolatedDevMode = isIsolatedDevMode
    }

    /// Registra el atajo de teclado global en el despachador de eventos de macOS.
    /// - Parameter action: Clausura a ejecutar cuando se presione el atajo.
    public func registerDefaultShortcut(action: @escaping () -> Void) {
        self.onHotKeyTriggered = action
        unregister()

        // Por defecto: Cmd + Shift + G (keyCode 5 es la tecla 'G')
        // En desarrollo aislado: Cmd + Option + Shift + G para evitar colisiones con la versión oficial instalada.
        let keyCode: UInt32 = 5
        let modifiers: UInt32 = isIsolatedDevMode
            ? UInt32(cmdKey | optionKey | shiftKey)
            : UInt32(cmdKey | shiftKey)

        let signature: OSType = isIsolatedDevMode ? OSType(0x47444556) : OSType(0x47454D49) // 'GDEV' vs 'GEMI'
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)

        if status == noErr {
            let label = isIsolatedDevMode ? "Cmd+Option+Shift+G (Isolated Dev)" : "Cmd+Shift+G"
            print("[GlobalHotkey] Registrado exitosamente: \(label)")
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData else { return noErr }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.onHotKeyTriggered?()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }

    /// Libera los recursos de Carbon y desregistra el atajo activo del sistema operativo.
    public func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    deinit {
        unregister()
    }
}
