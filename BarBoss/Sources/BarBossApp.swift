import SwiftUI
import AppKit

@main
struct BarBossApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app runs as an agent / accessory (no Dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Start Menu Bar Manager
        MenuBarManager.shared.start {
            SettingsWindowController.shared.showWindow()
        }
        
        // Start Hotkey and Hover managers
        HotkeyManager.shared.start()
        HoverManager.shared.start()
        
        // Initialize Sparkle Updater
        _ = UpdateManager.shared
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.stop()
        HoverManager.shared.stop()
    }
}
