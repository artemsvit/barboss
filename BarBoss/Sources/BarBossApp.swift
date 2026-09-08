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
        
        // Listen for open settings notifications
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.barboss.OpenSettings"),
            object: nil,
            queue: .main
        ) { _ in
            SettingsWindowController.shared.showWindow()
        }

        if CommandLine.arguments.contains("--settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                SettingsWindowController.shared.showWindow()
            }
        }
        
        if CommandLine.arguments.contains("--onboarding-permissions") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                OnboardingWindowController.shared.showWindow(initialStep: .permissions)
            }
        } else if CommandLine.arguments.contains("--onboarding-select") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                OnboardingWindowController.shared.showWindow(initialStep: .selectApps)
            }
        } else if CommandLine.arguments.contains("--onboarding") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                OnboardingWindowController.shared.showWindow(initialStep: .welcome)
            }
        }
        
        // Show onboarding on first launch
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "BarBoss_hasCompletedOnboarding")
        if !hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                OnboardingWindowController.shared.showWindow()
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        MenuBarManager.shared.stop()
        HotkeyManager.shared.stop()
        HoverManager.shared.stop()
    }
}
