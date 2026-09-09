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
    
    private var isScanning = false
    private let scanQueue = DispatchQueue(label: "com.barboss.scanner", qos: .userInitiated)
    
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
        setupWorkspaceObservers()
    }
    
    private func setupWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.scanItems()
        }
        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.scanItems()
        }
    }
    
    public func scanItems() {
        scanQueue.async { [weak self] in
            guard let self = self else { return }
            if self.isScanning { return }
            self.isScanning = true
            defer { self.isScanning = false }
            
            let items = self.performScan()
            DispatchQueue.main.async {
                self.discoveredItems = items
            }
        }
    }
    
    private func performScan() -> [DiscoveredMenuBarItem] {
        var items: [DiscoveredMenuBarItem] = []
        var seenBundleIds = Set<String>()
        
        // 1. Direct scan from MenuBarAgent (macOS 27+)
        if let mba = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.MenuBarAgent" }) {
            let root = AXUIElementCreateApplication(mba.processIdentifier)
            var windowsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(root, kAXChildrenAttribute as CFString, &windowsRef) == .success,
               let windows = windowsRef as? [AXUIElement] {
                for win in windows {
                    var subRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(win, kAXChildrenAttribute as CFString, &subRef) == .success,
                       let subs = subRef as? [AXUIElement] {
                        for sub in subs {
                            var childrenRef: CFTypeRef?
                            if AXUIElementCopyAttributeValue(sub, "AXChildren" as CFString, &childrenRef) == .success,
                               let children = childrenRef as? [AXUIElement], let first = children.first {
                                var pid: pid_t = 0
                                if AXUIElementGetPid(first, &pid) == .success && pid > 0 {
                                    if let app = NSRunningApplication(processIdentifier: pid),
                                       let bundleId = app.bundleIdentifier,
                                       let name = app.localizedName,
                                       !name.isEmpty,
                                       bundleId != "com.barboss.app",
                                       bundleId != "com.apple.MenuBarAgent",
                                       !self.ignoredBundlePrefixes.contains(where: { bundleId.hasPrefix($0) }) {
                                        if !seenBundleIds.contains(bundleId) {
                                            seenBundleIds.insert(bundleId)
                                            items.append(DiscoveredMenuBarItem(
                                                id: bundleId,
                                                name: name,
                                                bundleIdentifier: bundleId,
                                                processIdentifier: pid,
                                                icon: app.icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: name)
                                            ))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 2. Fallback for older macOS (or if MenuBarAgent direct query returned nothing)
        if items.isEmpty {
            let runningApps = NSWorkspace.shared.runningApplications
            for app in runningApps {
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName,
                      !name.isEmpty,
                      bundleId != "com.barboss.app",
                      !self.ignoredBundlePrefixes.contains(where: { bundleId.hasPrefix($0) }) else { continue }
                
                if app.activationPolicy == .accessory && !bundleId.hasPrefix("com.apple.") {
                    if !seenBundleIds.contains(bundleId) {
                        seenBundleIds.insert(bundleId)
                        items.append(DiscoveredMenuBarItem(
                            id: bundleId,
                            name: name,
                            bundleIdentifier: bundleId,
                            processIdentifier: app.processIdentifier,
                            icon: app.icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: name)
                        ))
                    }
                }
            }
        }
        
        // 3. ALWAYS include user-configured hidden items from Preferences
        // Even if they are currently suppressed from the menu bar or closed
        let hiddenItemIds = Preferences.shared.hiddenItemIdentifiers
        for bundleId in hiddenItemIds {
            guard !bundleId.isEmpty, !seenBundleIds.contains(bundleId) else { continue }
            seenBundleIds.insert(bundleId)
            
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }),
               let name = app.localizedName, !name.isEmpty {
                items.append(DiscoveredMenuBarItem(
                    id: bundleId,
                    name: name,
                    bundleIdentifier: bundleId,
                    processIdentifier: app.processIdentifier,
                    icon: app.icon ?? NSImage(systemSymbolName: "app.fill", accessibilityDescription: name)
                ))
            } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                let name = FileManager.default.displayName(atPath: appURL.path)
                let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                items.append(DiscoveredMenuBarItem(
                    id: bundleId,
                    name: name,
                    bundleIdentifier: bundleId,
                    processIdentifier: 0,
                    icon: icon
                ))
            } else {
                let fallbackName = bundleId.components(separatedBy: ".").last?.capitalized ?? bundleId
                items.append(DiscoveredMenuBarItem(
                    id: bundleId,
                    name: fallbackName,
                    bundleIdentifier: bundleId,
                    processIdentifier: 0,
                    icon: NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil)
                ))
            }
        }
        
        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
}
