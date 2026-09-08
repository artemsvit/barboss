import AppKit
import SwiftUI
import Combine

public final class MenuBarManager: NSObject, NSMenuDelegate {
    public static let shared = MenuBarManager()
    
    private var primaryStatusItem: NSStatusItem!
    private var hiddenSeparatorItem: NSStatusItem!
    private var alwaysHiddenSeparatorItem: NSStatusItem?
    
    private var autoHideTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
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
        // 1. Primary BarBoss status item (Toggle & Menu)
        primaryStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        primaryStatusItem.autosaveName = "BarBoss_PrimaryItem"
        
        if let button = primaryStatusItem.button {
            button.target = self
            button.action = #selector(handlePrimaryItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "BarBoss (Click to toggle hidden items, Right-click for menu)"
        }
        
        // 2. Hidden separator item
        hiddenSeparatorItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        hiddenSeparatorItem.autosaveName = "BarBoss_HiddenSeparator"
        
        if let sepButton = hiddenSeparatorItem.button {
            sepButton.target = self
            sepButton.action = #selector(handleSeparatorClick(_:))
            sepButton.toolTip = "BarBoss Separator (⌘-drag icons to the left of this separator)"
        }
        
        // 3. Always hidden separator item (if enabled)
        if Preferences.shared.showAlwaysHiddenSection {
            setupAlwaysHiddenItem()
        }
    }
    
    private func setupAlwaysHiddenItem() {
        if alwaysHiddenSeparatorItem == nil {
            alwaysHiddenSeparatorItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            alwaysHiddenSeparatorItem?.autosaveName = "BarBoss_AlwaysHiddenSeparator"
            if let button = alwaysHiddenSeparatorItem?.button {
                button.title = "‖"
                button.toolTip = "BarBoss Always Hidden (Items to the left stay hidden)"
            }
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
        
        prefs.$menuBarIconStyle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePrimaryButtonAppearance()
            }
            .store(in: &cancellables)
        
        prefs.$separatorStyle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateSeparatorAppearance()
            }
            .store(in: &cancellables)
        
        prefs.$showAlwaysHiddenSection
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                if show {
                    self?.setupAlwaysHiddenItem()
                } else {
                    self?.alwaysHiddenSeparatorItem = nil
                }
            }
            .store(in: &cancellables)
    }
    
    @objc private func handlePrimaryItemClick(_ sender: NSStatusBarButton) {
        guard let currentEvent = NSApp.currentEvent else { return }
        
        // Right click or Control-click opens contextual menu
        if currentEvent.type == .rightMouseUp || (currentEvent.modifierFlags.contains(.control)) {
            showContextMenu()
            return
        }
        
        // Left click toggles based on mode
        let prefs = Preferences.shared
        switch prefs.hideMode {
        case .inline:
            toggleHiddenItems()
        case .floatingBar:
            FloatingBarController.shared.toggle(relativeTo: sender) { [weak self] in
                self?.onOpenSettings?()
            }
        }
    }
    
    @objc private func handleSeparatorClick(_ sender: NSStatusBarButton) {
        // Clicking separator collapses hidden items back
        if !Preferences.shared.isHidden {
            toggleHiddenItems()
        }
    }
    
    public func toggleHiddenItems() {
        let prefs = Preferences.shared
        prefs.isHidden.toggle()
        
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
    
    private func updateItemStates() {
        updatePrimaryButtonAppearance()
        updateSeparatorAppearance()
        
        let isHidden = Preferences.shared.isHidden
        let hideMode = Preferences.shared.hideMode
        
        if hideMode == .inline {
            if isHidden {
                // Collapsed: Separator pushes items out of the visible area
                hiddenSeparatorItem.length = 10000
                hiddenSeparatorItem.button?.title = ""
            } else {
                // Expanded: Normal width, showing separator glyph
                hiddenSeparatorItem.length = NSStatusItem.variableLength
                hiddenSeparatorItem.button?.title = " " + Preferences.shared.separatorStyle.symbol + " "
            }
        } else {
            // In floating bar mode, separator is compact
            hiddenSeparatorItem.length = NSStatusItem.variableLength
            hiddenSeparatorItem.button?.title = " " + Preferences.shared.separatorStyle.symbol + " "
        }
    }
    
    private func updatePrimaryButtonAppearance() {
        guard let button = primaryStatusItem?.button else { return }
        
        let isHidden = Preferences.shared.isHidden
        let style = Preferences.shared.menuBarIconStyle
        
        let symbolName: String
        switch style {
        case .pug:
            symbolName = isHidden ? "sunglasses" : "sunglasses.fill"
        case .bowtie:
            symbolName = isHidden ? "suit.diamond" : "suit.diamond.fill"
        case .martini:
            symbolName = isHidden ? "wineglass" : "wineglass.fill"
        case .bars:
            symbolName = isHidden ? "line.3.horizontal" : "line.3.horizontal.decrease.circle.fill"
        case .dot:
            symbolName = isHidden ? "circle" : "circle.fill"
        }
        
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "BarBoss")?.withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
        }
    }
    
    private func updateSeparatorAppearance() {
        guard let sepButton = hiddenSeparatorItem?.button else { return }
        let isHidden = Preferences.shared.isHidden
        if !isHidden {
            sepButton.title = " " + Preferences.shared.separatorStyle.symbol + " "
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
        
        let isHidden = Preferences.shared.isHidden
        
        // 1. Toggle Item
        let toggleTitle = isHidden ? "Show Hidden Items" : "Hide Hidden Items"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(contextToggleHiddenItems), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        // 2. Open BarBoss Bar
        let barItem = NSMenuItem(title: "Show BarBoss Bar", action: #selector(contextShowFloatingBar), keyEquivalent: "")
        barItem.target = self
        menu.addItem(barItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(contextOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // 4. Sparkle Check for Updates
        let updatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(contextCheckForUpdates), keyEquivalent: "")
        updatesItem.target = self
        menu.addItem(updatesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Quit
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
    
    @objc private func contextShowFloatingBar() {
        FloatingBarController.shared.show(relativeTo: primaryStatusItem.button) { [weak self] in
            self?.onOpenSettings?()
        }
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
}
