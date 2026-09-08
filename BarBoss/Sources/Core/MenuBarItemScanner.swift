import AppKit
import ApplicationServices

public struct DiscoveredMenuBarItem: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let bundleIdentifier: String
    public let processIdentifier: pid_t
    public let icon: NSImage?
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: DiscoveredMenuBarItem, rhs: DiscoveredMenuBarItem) -> Bool {
        lhs.id == rhs.id
    }
}

public final class MenuBarItemScanner: ObservableObject {
    public static let shared = MenuBarItemScanner()
    
    @Published public var discoveredItems: [DiscoveredMenuBarItem] = []
    
    // System daemons to ignore (they don't have user menu bar icons)
    private let ignoredBundlePrefixes = [
        "com.apple.loginwindow",
        "com.apple.WindowManager",
        "com.apple.wallpaper",
        "com.apple.coreservices",
        "com.apple.WebKit",
        "com.apple.accessibility.AXVisualSupportAgent",
        "com.apple.dock.extra",
        "com.apple.dock.external",
        "com.apple.notificationcenterui",
        "com.apple.universalcontrol",
        "com.apple.campo",
        "com.apple.TextInputMenuAgent",
        "com.apple.AirPlayUIAgent",
        "com.apple.CoreLocationAgent",
        "com.apple.UserNotificationCenter",
        "com.apple.SoftwareUpdateNotificationManager",
        "com.apple.universalAccessAuthWarn"
    ]
    
    private init() {
        scanItems()
    }
    
    public func scanItems() {
        var items: [DiscoveredMenuBarItem] = []
        var seenBundleIds = Set<String>()
        
        let runningApps = NSWorkspace.shared.runningApplications
        
        for app in runningApps {
            guard let bundleId = app.bundleIdentifier,
                  let name = app.localizedName,
                  !name.isEmpty,
                  bundleId != "com.barboss.app" else { continue }
            
            // Filter system background daemons
            if ignoredBundlePrefixes.contains(where: { bundleId.hasPrefix($0) }) {
                continue
            }
            
            // Check if app has status bar items / accessory policy
            let isAccessory = app.activationPolicy == .accessory
            let hasMenuBarAX = checkAppHasMenuBar(pid: app.processIdentifier)
            
            if (isAccessory && hasMenuBarAX) || (isAccessory && !bundleId.hasPrefix("com.apple.")) || hasMenuBarAX {
                if !seenBundleIds.contains(bundleId) {
                    seenBundleIds.insert(bundleId)
                    
                    let item = DiscoveredMenuBarItem(
                        id: bundleId,
                        name: name,
                        bundleIdentifier: bundleId,
                        processIdentifier: app.processIdentifier,
                        icon: app.icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: name)
                    )
                    items.append(item)
                }
            }
        }
        
        // Sort alphabetically by name
        self.discoveredItems = items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private func checkAppHasMenuBar(pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        var children: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &children) == .success,
           let childList = children as? [AXUIElement] {
            for child in childList {
                var role: AnyObject?
                AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
                if let r = role as? String, r == "AXMenuBar" || r == "AXMenuExtra" || r == "AXMenuBarItem" {
                    return true
                }
            }
        }
        return false
    }
    
    public func activateApp(bundleIdentifier: String) {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }
}
