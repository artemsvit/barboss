import SwiftUI
import ServiceManagement

public enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case glasses = "glasses"
    
    public var id: String { rawValue }
    public var title: String { "BarBoss Glasses" }
    public var systemImageName: String { "sunglasses.fill" }
}

public enum SeparatorStyle: String, CaseIterable, Identifiable {
    case pipe = "pipe"
    case chevron = "chevron"
    case dot = "dot"
    case slash = "slash"
    
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .pipe: return "Vertical Bar (|)"
        case .chevron: return "Chevron"
        case .dot: return "Bullet"
        case .slash: return "Slash"
        }
    }
    public var symbol: String {
        switch self {
        case .pipe: return "|"
        case .chevron: return "›"
        case .dot: return "•"
        case .slash: return "/"
        }
    }
}

public final class Preferences: ObservableObject {
    public static let shared = Preferences()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let isHidden = "BarBoss_isHidden"
        static let autoHideDelay = "BarBoss_autoHideDelay"
        static let hoverToReveal = "BarBoss_hoverToReveal"
        static let showAlwaysHiddenSection = "BarBoss_showAlwaysHiddenSection"
        static let menuBarIconStyle = "BarBoss_menuBarIconStyle"
        static let separatorStyle = "BarBoss_separatorStyle"
        static let hotkeyModifiers = "BarBoss_hotkeyModifiers"
        static let hotkeyKeyCode = "BarBoss_hotkeyKeyCode"
        static let hiddenItemIdentifiers = "BarBoss_hiddenItemIdentifiers"
        static let sparkleAutoCheck = "SUEnableAutomaticChecks"
        static let sparkleAutoDownload = "SUAutomaticallyUpdate"
    }
    
    @Published public var isHidden: Bool {
        didSet { defaults.set(isHidden, forKey: Keys.isHidden) }
    }
    
    @Published public var autoHideDelay: Double {
        didSet { defaults.set(autoHideDelay, forKey: Keys.autoHideDelay) }
    }
    
    @Published public var hoverToReveal: Bool {
        didSet { defaults.set(hoverToReveal, forKey: Keys.hoverToReveal) }
    }
    
    @Published public var showAlwaysHiddenSection: Bool {
        didSet { defaults.set(showAlwaysHiddenSection, forKey: Keys.showAlwaysHiddenSection) }
    }
    
    @Published public var menuBarIconStyle: MenuBarIconStyle {
        didSet { defaults.set(menuBarIconStyle.rawValue, forKey: Keys.menuBarIconStyle) }
    }
    
    @Published public var separatorStyle: SeparatorStyle {
        didSet { defaults.set(separatorStyle.rawValue, forKey: Keys.separatorStyle) }
    }
    
    @Published public var hotkeyModifiers: UInt {
        didSet { defaults.set(hotkeyModifiers, forKey: Keys.hotkeyModifiers) }
    }
    
    @Published public var hotkeyKeyCode: UInt16 {
        didSet { defaults.set(hotkeyKeyCode, forKey: Keys.hotkeyKeyCode) }
    }
    
    @Published public var hiddenItemIdentifiers: [String] {
        didSet { defaults.set(hiddenItemIdentifiers, forKey: Keys.hiddenItemIdentifiers) }
    }
    
    @Published public var launchAtLogin: Bool = false {
        didSet { setLaunchAtLogin(launchAtLogin) }
    }
    
    private init() {
        self.isHidden = defaults.object(forKey: Keys.isHidden) != nil ? defaults.bool(forKey: Keys.isHidden) : false
        
        self.autoHideDelay = defaults.object(forKey: Keys.autoHideDelay) != nil ? defaults.double(forKey: Keys.autoHideDelay) : 5.0
        self.hoverToReveal = defaults.bool(forKey: Keys.hoverToReveal)
        self.showAlwaysHiddenSection = defaults.bool(forKey: Keys.showAlwaysHiddenSection)
        
        self.menuBarIconStyle = .glasses
        
        let savedSeparatorStyle = defaults.string(forKey: Keys.separatorStyle) ?? SeparatorStyle.pipe.rawValue
        self.separatorStyle = SeparatorStyle(rawValue: savedSeparatorStyle) ?? .pipe
        
        // Default hotkey: Command + Shift + B (B = keyCode 11)
        self.hotkeyModifiers = defaults.object(forKey: Keys.hotkeyModifiers) != nil ? UInt(defaults.integer(forKey: Keys.hotkeyModifiers)) : (NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        self.hotkeyKeyCode = defaults.object(forKey: Keys.hotkeyKeyCode) != nil ? UInt16(defaults.integer(forKey: Keys.hotkeyKeyCode)) : 11
        
        self.hiddenItemIdentifiers = defaults.stringArray(forKey: Keys.hiddenItemIdentifiers) ?? []
        
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }
    
    public func isItemHidden(_ id: String) -> Bool {
        hiddenItemIdentifiers.contains(id)
    }
    
    public func toggleItemHidden(_ id: String) {
        if isItemHidden(id) {
            hiddenItemIdentifiers.removeAll { $0 == id }
        } else {
            hiddenItemIdentifiers.append(id)
        }
    }
    
    public func hideItem(_ id: String) {
        if !hiddenItemIdentifiers.contains(id) {
            hiddenItemIdentifiers.append(id)
        }
    }
    
    public func showItem(_ id: String) {
        hiddenItemIdentifiers.removeAll { $0 == id }
    }
    
    private func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            print("BarBoss: Error changing launch at login state: \(error.localizedDescription)")
        }
    }
}
