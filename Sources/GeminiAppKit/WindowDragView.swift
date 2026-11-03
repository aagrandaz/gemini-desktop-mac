//
//  WindowDragView.swift
//  GeminiAppKit
//
//  Autor: aagrandaz@gmail.com
//

import SwiftUI
import AppKit

/// An invisible drag region that initiates window dragging on mouseDown
public struct WindowDragView: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> WindowDragNSView {
        WindowDragNSView()
    }

    public func updateNSView(_ nsView: WindowDragNSView, context: Context) {}
}

public final class WindowDragNSView: NSView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTrackingArea()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTrackingArea()
    }

    private func setupTrackingArea() {
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
    }

    public override func mouseEntered(with event: NSEvent) {
        NSCursor.openHand.set()
    }

    public override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    public override func mouseDown(with event: NSEvent) {
        NSCursor.closedHand.set()
        window?.performDrag(with: event)
    }

    public override func mouseUp(with event: NSEvent) {
        NSCursor.openHand.set()
    }
}
