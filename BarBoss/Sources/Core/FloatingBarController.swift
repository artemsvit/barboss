import AppKit
import SwiftUI

public final class FloatingBarController: NSObject {
    public static let shared = FloatingBarController()
    
    private var panel: NSPanel?
    private var eventMonitor: Any?
    
    private override init() {
        super.init()
    }
    
    public func toggle(relativeTo statusItemButton: NSStatusBarButton?, onOpenSettings: @escaping () -> Void) {
        if let panel = panel, panel.isVisible {
            hide()
        } else {
            show(relativeTo: statusItemButton, onOpenSettings: onOpenSettings)
        }
    }
    
    public func show(relativeTo statusItemButton: NSStatusBarButton?, onOpenSettings: @escaping () -> Void) {
        if panel == nil {
            createPanel(onOpenSettings: onOpenSettings)
        }
        
        guard let panel = panel else { return }
        
        // Position panel right below the menu bar item or centered under the notch/top bar
        let screen = statusItemButton?.window?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let menuBarHeight = screenFrame.maxY - visibleFrame.maxY
        
        let panelWidth: CGFloat = 360
        let panelHeight: CGFloat = 110
        
        var xPos: CGFloat
        if let button = statusItemButton, let window = button.window {
            let buttonFrameInWindow = button.convert(button.bounds, to: nil)
            let buttonScreenFrame = window.convertToScreen(buttonFrameInWindow)
            xPos = buttonScreenFrame.midX - (panelWidth / 2)
        } else {
            xPos = screenFrame.midX - (panelWidth / 2)
        }
        
        // Ensure panel stays on screen
        xPos = max(screenFrame.minX + 10, min(xPos, screenFrame.maxX - panelWidth - 10))
        let yPos = screenFrame.maxY - menuBarHeight - panelHeight - 6
        
        panel.setFrame(NSRect(x: xPos, y: yPos, width: panelWidth, height: panelHeight), display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }
        
        // Click-outside dismissal
        if Preferences.shared.hideOnClickOutside {
            setupOutsideClickMonitor()
        }
    }
    
    public func hide() {
        guard let panel = panel, panel.isVisible else { return }
        removeOutsideClickMonitor()
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
    
    public var isVisible: Bool {
        panel?.isVisible ?? false
    }
    
    private func createPanel(onOpenSettings: @escaping () -> Void) {
        let floatingPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 110),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        floatingPanel.isFloatingPanel = true
        floatingPanel.level = .floating
        floatingPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        floatingPanel.backgroundColor = .clear
        floatingPanel.isOpaque = false
        floatingPanel.hasShadow = false
        floatingPanel.isMovableByWindowBackground = true
        
        let contentView = FloatingBarView(
            onClose: { [weak self] in
                self?.hide()
            },
            onOpenSettings: { [weak self] in
                self?.hide()
                onOpenSettings()
            }
        )
        
        floatingPanel.contentView = NSHostingView(rootView: contentView)
        self.panel = floatingPanel
    }
    
    private func setupOutsideClickMonitor() {
        removeOutsideClickMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.panel, panel.isVisible else { return }
            let mouseLocation = NSEvent.mouseLocation
            if !panel.frame.contains(mouseLocation) {
                self.hide()
            }
        }
    }
    
    private func removeOutsideClickMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
