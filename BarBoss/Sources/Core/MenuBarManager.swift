import AppKit
import SwiftUI
import Combine
import Darwin
import ObjectiveC.runtime

public final class MenuBarManager: NSObject, NSMenuDelegate {
    public static let shared = MenuBarManager()
    
    private var primaryStatusItem: NSStatusItem!
    
    private var autoHideTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let modernVisibilityController = ModernMenuBarVisibilityController()
    
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
        // Clean up legacy separator keys from UserDefaults
        let sepKey = "NSStatusItem Preferred Position BarBoss_HiddenSeparator"
        let visibleCCKey = "NSStatusItem VisibleCC BarBoss_HiddenSeparator"
        UserDefaults.standard.removeObject(forKey: sepKey)
        UserDefaults.standard.removeObject(forKey: visibleCCKey)
        
        let primaryKey = "NSStatusItem Preferred Position BarBoss_PrimaryItem"
        let currentPrimary = UserDefaults.standard.double(forKey: primaryKey)
        if currentPrimary <= 0 || UserDefaults.standard.object(forKey: primaryKey) == nil {
            UserDefaults.standard.set(200.0, forKey: primaryKey)
        }
        UserDefaults.standard.synchronize()
        syncMenuBarAgentPreferencesIfNeeded()
        
        // Primary BarBoss status item (Toggle & Menu)
        primaryStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        primaryStatusItem.autosaveName = "BarBoss_PrimaryItem"
        
        if let button = primaryStatusItem.button {
            button.target = self
            button.action = #selector(handlePrimaryItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "BarBoss Glasses (Click to toggle hidden items, Right-click for menu)"
        }
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
        
        // Left click (or click without right/control modifier) toggles hidden items
        toggleHiddenItems()
    }
    
    public func toggleHiddenItems() {
        let prefs = Preferences.shared
        prefs.isHidden.toggle()
        
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
    }

    public func stop() {
        stopAutoHideTimer()
        modernVisibilityController.showAll()
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
        
        // 1. Toggle Items
        let toggleTitle = Preferences.shared.isHidden ? "Show Items" : "Hide Items"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(contextToggleHiddenItems), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(contextOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // 3. Sparkle Check for Updates
        let updatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(contextCheckForUpdates), keyEquivalent: "")
        updatesItem.target = self
        menu.addItem(updatesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Quit
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
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 else { return }
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
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
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
