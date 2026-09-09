import AppKit
import Combine
import Darwin
import ObjectiveC.runtime
import OSLog
import ApplicationServices

public final class MenuBarManager: NSObject, NSMenuDelegate {
    public static let shared = MenuBarManager()
    
    private var primaryStatusItem: NSStatusItem!
    private var legacySeparatorItem: NSStatusItem?
    
    private var autoHideTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let modernVisibilityController = ModernMenuBarVisibilityController()
    private let legacyItemArranger = LegacyMenuBarItemArranger()
    private let logger = Logger(subsystem: "com.barboss.app", category: "MenuBarVisibility")
    
    public var onOpenSettings: (() -> Void)?
    
    private override init() {
        super.init()
    }
    
    public func start(onOpenSettings: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        setupStatusItems()
        setupObservers()
        updateItemStates()
    }
    
    private func setupStatusItems() {
        // macOS 27 can hide selected applications directly. Older versions use
        // the established separator technique, so preserve its saved position.
        let sepKey = "NSStatusItem Preferred Position BarBoss_HiddenSeparator"
        let visibleCCKey = "NSStatusItem VisibleCC BarBoss_HiddenSeparator"
        let primaryKey = "NSStatusItem Preferred Position BarBoss_PrimaryItem"
        if modernVisibilityController.isSupported {
            UserDefaults.standard.removeObject(forKey: sepKey)
            UserDefaults.standard.removeObject(forKey: visibleCCKey)
            syncMenuBarAgentPreferencesIfNeeded()
            let currentPrimary = UserDefaults.standard.double(forKey: primaryKey)
            if currentPrimary <= 0 || UserDefaults.standard.object(forKey: primaryKey) == nil {
                UserDefaults.standard.set(200.0, forKey: primaryKey)
            }
        } else if UserDefaults.standard.object(forKey: sepKey) == nil {
            // Put the control and separator next to each other on first launch
            // (or when upgrading from the 27-only implementation). Their saved
            // positions remain user-draggable after this one-time migration.
            UserDefaults.standard.set(0.0, forKey: primaryKey)
            UserDefaults.standard.set(1.0, forKey: sepKey)
        }
        UserDefaults.standard.synchronize()
        
        // Primary BarBoss status item (Toggle & Menu)
        primaryStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        primaryStatusItem.autosaveName = "BarBoss_PrimaryItem"
        
        if let button = primaryStatusItem.button {
            button.target = self
            button.action = #selector(handlePrimaryItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "BarBoss Glasses (Click to toggle hidden items, Right-click for menu)"
        }

        if !modernVisibilityController.isSupported {
            setupLegacySeparatorItem()
        }
    }

    private func setupLegacySeparatorItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "BarBoss_HiddenSeparator"
        if let button = item.button {
            button.title = " | "
            button.toolTip = "Hold Command and drag icons to the left of this separator"
        }
        legacySeparatorItem = item
        logger.info("Using macOS 26-compatible separator visibility backend")
    }
    
    private func setupObservers() {
        let prefs = Preferences.shared
        
        prefs.$isHidden
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateItemStates()
            }
            .store(in: &cancellables)
        
        prefs.$hiddenItemIdentifiers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] identifiers in
                self?.updateItemStates()
                self?.arrangeLegacyItemsIfNeeded(identifiers)
            }
            .store(in: &cancellables)

        let workspaceNotifications = NSWorkspace.shared.notificationCenter
        Publishers.Merge(
            workspaceNotifications.publisher(for: NSWorkspace.didLaunchApplicationNotification),
            workspaceNotifications.publisher(for: NSWorkspace.didTerminateApplicationNotification)
        )
        .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.updateItemStates()
            MenuBarItemScanner.shared.scanItems()
            self?.arrangeLegacyItemsIfNeeded(Preferences.shared.hiddenItemIdentifiers)
        }
        .store(in: &cancellables)
    }
    
    @objc private func handlePrimaryItemClick(_ sender: NSStatusBarButton) {
        if let currentEvent = NSApp.currentEvent,
           currentEvent.type == .rightMouseUp || currentEvent.modifierFlags.contains(.control) {
            showContextMenu()
            return
        }

        // Native selected-item visibility is available starting with macOS 26.
        // On older systems, open Settings so clicking BarBoss is never a no-op.
        guard modernVisibilityController.isSupported else {
            onOpenSettings?()
            return
        }

        toggleHiddenItems()
    }
    
    public func toggleHiddenItems() {
        guard modernVisibilityController.isSupported else {
            onOpenSettings?()
            return
        }

        let prefs = Preferences.shared
        prefs.isHidden.toggle()

        logger.info("Toggle requested: hidden=\(prefs.isHidden, privacy: .public), selectedItems=\(prefs.hiddenItemIdentifiers.count, privacy: .public)")
        updateItemStates()
        arrangeLegacyItemsIfNeeded(prefs.hiddenItemIdentifiers)
        
        if !prefs.isHidden && prefs.autoHideDelay > 0 {
            startAutoHideTimer()
        } else {
            stopAutoHideTimer()
        }
    }
    
    public func showHiddenItems() {
        if Preferences.shared.isHidden {
            toggleHiddenItems()
        }
    }
    
    public func hideHiddenItems() {
        if !Preferences.shared.isHidden {
            toggleHiddenItems()
        }
    }
    
    public func updateItemStates() {
        updatePrimaryButtonAppearance()
        
        let isHidden = Preferences.shared.isHidden

        if modernVisibilityController.isSupported {
            if isHidden {
                modernVisibilityController.hide(
                    bundleIdentifiers: Set(Preferences.shared.hiddenItemIdentifiers)
                )
            } else {
                modernVisibilityController.showAll()
            }
            return
        }

        updateLegacyItemStates(isHidden: isHidden)
    }

    private func updateLegacyItemStates(isHidden: Bool) {
        guard let item = legacySeparatorItem else {
            logger.error("Legacy separator is unavailable; menu-bar items cannot be toggled")
            return
        }

        if isHidden {
            // NSStatusItem grows toward the left. Items placed to its left are
            // pushed beyond the available menu-bar area until it is collapsed.
            item.button?.title = ""
            item.length = 10_000
        } else {
            item.length = NSStatusItem.variableLength
            item.button?.title = " | "
        }
        logger.info("Applied separator visibility: hidden=\(isHidden, privacy: .public), length=\(item.length, privacy: .public)")
    }

    private func arrangeLegacyItemsIfNeeded(_ identifiers: [String]) {
        guard !modernVisibilityController.isSupported,
              let legacySeparatorItem else { return }

        legacyItemArranger.arrangeIfNeeded(
            selectedBundleIdentifiers: Set(identifiers),
            separatorItem: legacySeparatorItem,
            shouldRestoreHiddenState: Preferences.shared.isHidden
        ) { [weak self] message in
            self?.logger.info("\(message, privacy: .public)")
        }
    }

    public func stop() {
        stopAutoHideTimer()
        modernVisibilityController.showAll()
        if let legacySeparatorItem {
            legacySeparatorItem.length = NSStatusItem.variableLength
            legacySeparatorItem.button?.title = " | "
        }
        cancellables.removeAll()
    }
    
    private func updatePrimaryButtonAppearance() {
        guard let button = primaryStatusItem?.button else { return }
        
        let isHidden = Preferences.shared.isHidden
        let symbolName = isHidden ? "sunglasses" : "sunglasses.fill"
        
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "BarBoss Glasses")?.withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
        }
        
        if modernVisibilityController.isSupported {
            button.toolTip = isHidden ? "BarBoss Glasses (Click to show hidden items)" : "BarBoss Glasses (Click to hide items)"
        } else {
            button.toolTip = "BarBoss Glasses (Click to open Settings)"
        }
    }
    
    private func startAutoHideTimer() {
        stopAutoHideTimer()
        let delay = Preferences.shared.autoHideDelay
        guard delay > 0 else { return }
        
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.hideHiddenItems()
            }
        }
    }
    
    private func stopAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }
    
    private func showContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        
        if modernVisibilityController.isSupported {
            let toggleTitle = Preferences.shared.isHidden ? "Show Items" : "Hide Items"
            let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(contextToggleHiddenItems), keyEquivalent: "")
            toggleItem.target = self
            menu.addItem(toggleItem)
            menu.addItem(NSMenuItem.separator())
        }
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(contextOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // Sparkle Check for Updates
        let updatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(contextCheckForUpdates), keyEquivalent: "")
        updatesItem.target = self
        menu.addItem(updatesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit BarBoss", action: #selector(contextQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        primaryStatusItem.menu = menu
        primaryStatusItem.button?.performClick(nil)
    }
    
    public func menuDidClose(_ menu: NSMenu) {
        primaryStatusItem.menu = nil
    }
    
    @objc private func contextToggleHiddenItems() {
        toggleHiddenItems()
    }
    
    @objc private func contextOpenSettings() {
        onOpenSettings?()
    }
    
    @objc private func contextCheckForUpdates() {
        UpdateManager.shared.checkForUpdates()
    }
    
    @objc private func contextQuit() {
        NSApp.terminate(nil)
    }
    
    private func syncMenuBarAgentPreferencesIfNeeded() {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 else { return }
        let path = ("~/Library/Preferences/com.apple.MenuBarAgent.plist" as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url),
              var plist = try? PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil) as? [String: Any],
              var positions = plist["TrailingItemPreferredPositions"] as? [String: Any] else { return }
        
        let primaryKey = "status:com.barboss.app::BarBoss_PrimaryItem"
        let sepKey = "status:com.barboss.app::BarBoss_HiddenSeparator"
        
        var changed = false
        if (positions[primaryKey] as? NSNumber)?.doubleValue != 200.0 {
            positions[primaryKey] = 200.0
            changed = true
        }
        if positions.removeValue(forKey: sepKey) != nil {
            changed = true
        }
        
        if changed {
            plist["TrailingItemPreferredPositions"] = positions
            if let updatedData = try? PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0) {
                try? updatedData.write(to: url)
            }
        }
    }
}

/// On macOS 26 there is no per-bundle visibility assertion. This arranger uses
/// the system's Command-drag interaction to put only selected apps on the
/// hidden side of BarBoss's separator.
final class LegacyMenuBarItemArranger {
    private var pendingWorkItem: DispatchWorkItem?
    private var lastSignature = ""

    func arrangeIfNeeded(
        selectedBundleIdentifiers: Set<String>,
        separatorItem: NSStatusItem,
        shouldRestoreHiddenState: Bool,
        log: @escaping (String) -> Void
    ) {
        let runningSelected = NSWorkspace.shared.runningApplications
            .compactMap(\.bundleIdentifier)
            .filter(selectedBundleIdentifiers.contains)
            .sorted()
        let signature = runningSelected.isEmpty ? "<none>" : runningSelected.joined(separator: "|")
        guard signature != lastSignature else { return }

        pendingWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self, weak separatorItem] in
            guard let self, let separatorItem else { return }
            self.performArrangement(
                bundleIdentifiers: runningSelected,
                separatorItem: separatorItem,
                shouldRestoreHiddenState: shouldRestoreHiddenState,
                log: log
            )
        }
        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func performArrangement(
        bundleIdentifiers: [String],
        separatorItem: NSStatusItem,
        shouldRestoreHiddenState: Bool,
        log: @escaping (String) -> Void
    ) {
        guard AXIsProcessTrusted() else {
            log("Cannot arrange selected macOS 26 icons: Accessibility permission is missing")
            return
        }

        separatorItem.length = NSStatusItem.variableLength
        separatorItem.button?.title = " | "

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak separatorItem] in
            guard let self, let separatorItem else { return }
            guard let separator = self.separatorFrame(for: separatorItem) else {
                self.restore(separatorItem, hidden: shouldRestoreHiddenState)
                log("The macOS 26 separator frame is unavailable")
                return
            }

            let allItems = self.allThirdPartyMenuExtras()
            let leftEdge = allItems.map(\.frame.minX).min() ?? separator.minX
            let separatorDestination = CGPoint(
                x: max(24, leftEdge - separator.width - 12),
                y: separator.midY
            )

            self.commandDrag(from: separator.center, to: separatorDestination)
            self.moveSelectedItems(
                bundleIdentifiers: bundleIdentifiers,
                index: 0,
                separatorItem: separatorItem,
                restoreHidden: shouldRestoreHiddenState,
                log: log
            )
        }
    }

    private func moveSelectedItems(
        bundleIdentifiers: [String],
        index: Int,
        separatorItem: NSStatusItem,
        restoreHidden: Bool,
        log: @escaping (String) -> Void
    ) {
        guard index < bundleIdentifiers.count else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak separatorItem] in
                guard let self, let separatorItem else { return }
                let selectedItems = self.menuExtras(forBundleIdentifiers: bundleIdentifiers)
                let positionedCount: Int
                if let separator = self.separatorFrame(for: separatorItem) {
                    positionedCount = selectedItems.filter { $0.frame.midX < separator.midX }.count
                } else {
                    positionedCount = 0
                }
                if positionedCount == selectedItems.count {
                    self.lastSignature = bundleIdentifiers.isEmpty
                        ? "<none>"
                        : bundleIdentifiers.joined(separator: "|")
                }
                self.restore(separatorItem, hidden: restoreHidden)
                log("Positioned \(positionedCount) of \(selectedItems.count) selected macOS 26 menu-bar icon(s) behind the separator")
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self, weak separatorItem] in
            guard let self, let separatorItem else { return }
            let bundleIdentifier = bundleIdentifiers[index]
            if let item = self.menuExtras(forBundleIdentifiers: [bundleIdentifier]).first,
               let separator = self.separatorFrame(for: separatorItem) {
                let destination = CGPoint(
                    x: max(12, separator.minX - item.frame.width / 2 - 6),
                    y: separator.midY
                )
                self.commandDrag(from: item.frame.center, to: destination)
            }
            self.moveSelectedItems(
                bundleIdentifiers: bundleIdentifiers,
                index: index + 1,
                separatorItem: separatorItem,
                restoreHidden: restoreHidden,
                log: log
            )
        }
    }

    private func restore(_ separatorItem: NSStatusItem, hidden: Bool) {
        if hidden {
            separatorItem.button?.title = ""
            separatorItem.length = 10_000
        } else {
            separatorItem.length = NSStatusItem.variableLength
            separatorItem.button?.title = " | "
        }
    }

    private func commandDrag(from source: CGPoint, to destination: CGPoint) {
        guard let down = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: source,
            mouseButton: .left
        ), let dragged = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDragged,
            mouseCursorPosition: destination,
            mouseButton: .left
        ), let up = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: destination,
            mouseButton: .left
        ) else { return }

        down.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        usleep(40_000)
        dragged.flags = .maskCommand
        dragged.post(tap: .cghidEventTap)
        usleep(60_000)
        up.flags = .maskCommand
        up.post(tap: .cghidEventTap)
    }

    private struct MenuExtra {
        let frame: CGRect
    }

    private func separatorFrame(for separatorItem: NSStatusItem) -> CGRect? {
        guard let cocoaFrame = separatorItem.button?.window?.frame else { return nil }
        let mainDisplayHeight = CGDisplayBounds(CGMainDisplayID()).height
        return CGRect(
            x: cocoaFrame.minX,
            y: mainDisplayHeight - cocoaFrame.maxY,
            width: cocoaFrame.width,
            height: cocoaFrame.height
        )
    }

    private func menuExtras(forBundleIdentifiers identifiers: [String]) -> [MenuExtra] {
        let identifiers = Set(identifiers)
        return NSWorkspace.shared.runningApplications
            .filter { app in
                guard let bundleIdentifier = app.bundleIdentifier else { return false }
                return identifiers.contains(bundleIdentifier)
            }
            .flatMap { app in
                menuExtras(for: AXUIElementCreateApplication(app.processIdentifier))
                    .map { MenuExtra(frame: $0.frame) }
            }
    }

    private func allThirdPartyMenuExtras() -> [MenuExtra] {
        NSWorkspace.shared.runningApplications
            .filter { app in
                guard let id = app.bundleIdentifier else { return false }
                return !id.hasPrefix("com.apple.") && id != "com.barboss.app"
            }
            .flatMap { app in
                menuExtras(for: AXUIElementCreateApplication(app.processIdentifier))
                    .map { MenuExtra(frame: $0.frame) }
            }
    }

    private func menuExtras(for root: AXUIElement) -> [(frame: CGRect, title: String)] {
        var result: [(CGRect, String)] = []
        collectMenuExtras(in: root, depth: 0, result: &result)
        return result
    }

    private func collectMenuExtras(
        in element: AXUIElement,
        depth: Int,
        result: inout [(CGRect, String)]
    ) {
        guard depth <= 7 else { return }
        if attribute(kAXSubroleAttribute, from: element) == "AXMenuExtra",
           let frame = frame(of: element), frame.width > 0, frame.height > 0 {
            result.append((frame, attribute(kAXTitleAttribute, from: element) ?? ""))
        }
        for child in children(of: element) {
            collectMenuExtras(in: child, depth: depth + 1, result: &result)
        }
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else { return [] }
        return children
    }

    private func attribute(_ name: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let rawPosition = positionValue,
              let rawSize = sizeValue,
              CFGetTypeID(rawPosition) == AXValueGetTypeID(),
              CFGetTypeID(rawSize) == AXValueGetTypeID() else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(rawPosition as! AXValue, .cgPoint, &position),
              AXValueGetValue(rawSize as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

/// Small runtime bridge for the menu-bar assessment service introduced with
/// macOS 27. Keeping the bridge dynamic lets BarBoss continue to run on its
/// existing macOS 14 deployment target.
final class ModernMenuBarVisibilityController {
    private var agentProcess: Process?
    private var lastHiddenBundleIdentifiers = Set<String>()
    private var lastRunningBundleIdentifiers = Set<String>()

    var isSupported: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26
    }

    deinit {
        showAll()
    }

    func hide(bundleIdentifiers: Set<String>) {
        let hidden = bundleIdentifiers.filter { !$0.isEmpty }
        guard isSupported, !hidden.isEmpty else {
            showAll()
            return
        }

        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        if agentProcess?.isRunning == true,
           hidden == lastHiddenBundleIdentifiers,
           running == lastRunningBundleIdentifiers {
            return
        }

        stopAgent()
        lastHiddenBundleIdentifiers = hidden
        lastRunningBundleIdentifiers = running
        startAgent(hiddenBundleIDs: hidden)
    }

    func showAll() {
        stopAgent()
        lastHiddenBundleIdentifiers.removeAll()
        lastRunningBundleIdentifiers.removeAll()
    }

    private func stopAgent() {
        if let process = agentProcess, process.isRunning {
            process.terminate()
        }
        agentProcess = nil
    }

    private func startAgent(hiddenBundleIDs: Set<String>) {
        let executableURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/BarBossVisibilityAgent.app/Contents/MacOS/BarBossVisibilityAgent")
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            print("BarBoss: Menu-bar visibility agent is missing from the application bundle")
            return
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "--parent-pid", String(getpid()),
            "--hide", hiddenBundleIDs.sorted().joined(separator: ",")
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            agentProcess = process
        } catch {
            print("BarBoss: Unable to start menu-bar visibility agent: \(error.localizedDescription)")
        }
    }
}
