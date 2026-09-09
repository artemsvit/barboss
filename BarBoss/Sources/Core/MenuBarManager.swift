import AppKit
import Combine
import ObjectiveC.runtime
import OSLog

public final class MenuBarManager: NSObject, NSMenuDelegate {
    public static let shared = MenuBarManager()
    public static var supportsAutomaticItemSelection: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
    }
    
    private var primaryStatusItem: NSStatusItem!
    private var legacySeparatorItem: NSStatusItem?
    
    private var autoHideTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let modernVisibilityController = ModernMenuBarVisibilityController()
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
            .sink { [weak self] _ in
                self?.updateItemStates()
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
        }
        .store(in: &cancellables)
    }
    
    @objc private func handlePrimaryItemClick(_ sender: NSStatusBarButton) {
        if let currentEvent = NSApp.currentEvent,
           currentEvent.type == .rightMouseUp || currentEvent.modifierFlags.contains(.control) {
            showContextMenu()
            return
        }

        toggleHiddenItems()
    }
    
    public func toggleHiddenItems() {
        let prefs = Preferences.shared
        prefs.isHidden.toggle()

        logger.info("Toggle requested: hidden=\(prefs.isHidden, privacy: .public), selectedItems=\(prefs.hiddenItemIdentifiers.count, privacy: .public)")
        updateItemStates()
        
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
        
        button.toolTip = isHidden ? "BarBoss Glasses (Click to show hidden items)" : "BarBoss Glasses (Click to hide items)"
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
        
        let toggleTitle = Preferences.shared.isHidden ? "Show Items" : "Hide Items"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(contextToggleHiddenItems), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(NSMenuItem.separator())
        
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
        guard Self.supportsAutomaticItemSelection else { return }
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

/// Small runtime bridge for the menu-bar assessment service introduced with
/// macOS 27. Keeping the bridge dynamic lets BarBoss continue to run on its
/// existing macOS 14 deployment target.
final class ModernMenuBarVisibilityController {
    private var agentProcess: Process?
    private var lastHiddenBundleIdentifiers = Set<String>()
    private var lastRunningBundleIdentifiers = Set<String>()

    var isSupported: Bool {
        MenuBarManager.supportsAutomaticItemSelection
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
