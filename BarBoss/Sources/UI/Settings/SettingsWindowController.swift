import AppKit
import SwiftUI

public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    public func showWindow() {
        if window == nil {
            createWindow()
        }
        
        guard let window = window else { return }
        
        // Bring window to front and activate app
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    
    private func createWindow() {
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "BarBoss Settings"
        newWindow.styleMask = [.titled, .closable, .miniaturizable]
        newWindow.delegate = self
        newWindow.isReleasedWhenClosed = false
        newWindow.titlebarAppearsTransparent = false
        newWindow.center()
        
        self.window = newWindow
    }
    
    public func windowWillClose(_ notification: Notification) {
        // Keep window ready in memory for quick reopening
    }
}
