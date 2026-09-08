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
        
        // Show settings on first launch
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "BarBoss_hasLaunchedBefore")
        if !hasLaunchedBefore {
            UserDefaults.standard.set(true, forKey: "BarBoss_hasLaunchedBefore")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                SettingsWindowController.shared.showWindow()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.stop()
        HoverManager.shared.stop()
    }
}
