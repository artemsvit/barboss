import AppKit

public final class HoverManager {
    public static let shared = HoverManager()
    
    private var mouseMonitor: Any?
    private var isMouseInMenuBar = false
    
    private init() {}
    
    public func start() {
        stop()
        
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard Preferences.shared.hoverToReveal else { return }
            self?.checkMousePosition()
        }
    }
    
    public func stop() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }
    
    private func checkMousePosition() {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else { return }
        
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let menuBarHeight = screenFrame.maxY - visibleFrame.maxY
        let menuBarRect = NSRect(x: screenFrame.minX, y: screenFrame.maxY - menuBarHeight, width: screenFrame.width, height: menuBarHeight)
        
        let inside = menuBarRect.contains(mouseLocation)
        
        if inside && !isMouseInMenuBar {
            isMouseInMenuBar = true
            if Preferences.shared.isHidden {
                DispatchQueue.main.async {
                    MenuBarManager.shared.showHiddenItems()
                }
            }
        } else if !inside && isMouseInMenuBar {
            isMouseInMenuBar = false
            // Auto hide delay will take care of hiding if configured
        }
    }
}
