//
//  GlobalHotkeyManager.swift
//  GeminiDesktop
//

import AppKit
import Carbon

final class GlobalHotkeyManager: @unchecked Sendable {
    static let shared = GlobalHotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    var onHotKeyTriggered: (() -> Void)?

    func registerDefaultShortcut(action: @escaping () -> Void) {
        self.onHotKeyTriggered = action
        unregister()

        // Default: Cmd + Shift + G (keyCode 5 is 'g')
        let keyCode: UInt32 = 5
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)

        let hotKeyID = EventHotKeyID(signature: OSType(0x47454D49), id: 1) // 'GEMI'
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
        
        if status == noErr {
            print("[GlobalHotkey] Registered Cmd+Shift+G successfully")
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(GetEventDispatcherTarget(), { (_, event, _) -> OSStatus in
            GlobalHotkeyManager.shared.onHotKeyTriggered?()
            return noErr
        }, 1, &eventType, nil, &eventHandler)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}
