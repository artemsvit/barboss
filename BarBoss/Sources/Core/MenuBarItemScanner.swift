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
        
        // 1. Fast direct scan from MenuBarAgent on macOS 27+
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27,
           let mba = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.MenuBarAgent" }) {
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
    
    public func activateApp(bundleIdentifier: String, processIdentifier: pid_t? = nil) {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }),
           let modernRoot = modernMenuBarRoot(),
           let applicationElement = nestedApplication(named: app.localizedName ?? "", in: modernRoot),
           let menuExtra = firstMenuExtra(in: applicationElement, maximumDepth: 5) {
            AXUIElementPerformAction(menuExtra, kAXPressAction as CFString)
            return
        }

        if let pid = processIdentifier, pid > 0 {
            let appElement = AXUIElementCreateApplication(pid)
            if let menuExtra = firstMenuExtra(in: appElement, maximumDepth: 5) {
                AXUIElementPerformAction(menuExtra, kAXPressAction as CFString)
                return
            }
        }
        
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }

    private func modernMenuBarRoot() -> AXUIElement? {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27,
              let app = NSWorkspace.shared.runningApplications.first(where: {
                  $0.bundleIdentifier == "com.apple.MenuBarAgent"
              }) else { return nil }
        return AXUIElementCreateApplication(app.processIdentifier)
    }

    private func collectNestedApplicationNames(
        in element: AXUIElement,
        depth: Int,
        names: inout Set<String>
    ) {
        guard depth <= 8 else { return }
        // MenuBarAgent only nests application elements for processes that own
        // a status item. Some items (including Display Pilot) expose an empty
        // menu-extra subtree, so the application node itself is authoritative.
        if depth > 0,
           attribute(kAXRoleAttribute, from: element) == kAXApplicationRole,
           let name = attribute(kAXTitleAttribute, from: element),
           !name.isEmpty {
            names.insert(name)
        }
        for child in children(of: element) {
            collectNestedApplicationNames(in: child, depth: depth + 1, names: &names)
        }
    }

    private func nestedApplication(named name: String, in element: AXUIElement, depth: Int = 0) -> AXUIElement? {
        guard depth <= 8 else { return nil }
        if depth > 0,
           attribute(kAXRoleAttribute, from: element) == kAXApplicationRole,
           attribute(kAXTitleAttribute, from: element) == name {
            return element
        }
        for child in children(of: element) {
            if let result = nestedApplication(named: name, in: child, depth: depth + 1) {
                return result
            }
        }
        return nil
    }

    private func firstMenuExtra(in element: AXUIElement, maximumDepth: Int) -> AXUIElement? {
        guard maximumDepth >= 0 else { return nil }
        if attribute(kAXSubroleAttribute, from: element) == "AXMenuExtra" {
            return element
        }
        for child in children(of: element) {
            if let result = firstMenuExtra(in: child, maximumDepth: maximumDepth - 1) {
                return result
            }
        }
        return nil
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else { return [] }
        return children
    }

    private func attribute(_ name: String, from element: AXUIElement) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
