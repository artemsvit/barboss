import AppKit

public final class HotkeyManager {
    public static let shared = HotkeyManager()
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    private init() {}
    
    public func start() {
        stop()
        
        // Monitor global key downs
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // Monitor local key downs (when our app/settings is active)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
    }
    
    public func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let prefs = Preferences.shared
        let expectedModifiers = NSEvent.ModifierFlags(rawValue: prefs.hotkeyModifiers).intersection([.command, .option, .control, .shift])
        let eventModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        
        if event.keyCode == prefs.hotkeyKeyCode && eventModifiers == expectedModifiers {
            DispatchQueue.main.async {
                MenuBarManager.shared.toggleHiddenItems()
            }
            return true
        }
        return false
    }
}
