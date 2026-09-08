import AppKit
import SwiftUI

public final class OnboardingWindowController: NSObject, NSWindowDelegate {
    public static let shared = OnboardingWindowController()
    
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    public func showWindow(initialStep: OnboardingStep = .welcome) {
        createWindow(initialStep: initialStep)
        
        guard let window = window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    
    public func closeWindow() {
        window?.orderOut(nil)
    }
    
    private func createWindow(initialStep: OnboardingStep = .welcome) {
        let onboardingView = OnboardingView(initialStep: initialStep) { [weak self] in
            self?.closeWindow()
        }
        let hostingController = NSHostingController(rootView: onboardingView)
        
        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "Welcome to BarBoss"
        newWindow.styleMask = [.titled, .closable, .fullSizeContentView]
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true
        newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newWindow.delegate = self
        newWindow.isReleasedWhenClosed = false
        newWindow.isMovableByWindowBackground = true
        newWindow.center()
        
        self.window = newWindow
    }
    
    public func windowWillClose(_ notification: Notification) {
        // Cleanup if needed
    }
}
