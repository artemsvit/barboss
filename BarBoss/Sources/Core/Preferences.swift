import SwiftUI
import ServiceManagement

public enum HideMode: String, CaseIterable, Identifiable {
    case inline = "inline"
    case floatingBar = "floatingBar"
    
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .inline: return "Inline Menu Bar"
        case .floatingBar: return "BarBoss Bar (Floating)"
        }
    }
    public var description: String {
        switch self {
        case .inline: return "Collapses and expands items directly in the top menu bar."
        case .floatingBar: return "Shows hidden items in a sleek secondary bar beneath the menu bar."
        }
    }
}

public enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case pug = "pug"
    case bowtie = "bowtie"
    case martini = "martini"
    case bars = "bars"
    case dot = "dot"
    
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .pug: return "BarBoss Pug 🕶️"
        case .bowtie: return "Classic Bowtie"
        case .martini: return "Cocktail Glass"
        case .bars: return "Dynamic Bars"
        case .dot: return "Minimal Dot"
        }
    }
    public var systemImageName: String {
        switch self {
        case .pug: return "sunglasses.fill"
        case .bowtie: return "suit.diamond.fill"
        case .martini: return "wineglass.fill"
        case .bars: return "line.3.horizontal.decrease.circle"
        case .dot: return "circle.fill"
        }
    }
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
        case .chevron: return "Chevron (›)"
        case .dot: return "Bullet (•)"
        case .slash: return "Slash (/)"
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
        static let hideMode = "BarBoss_hideMode"
        static let autoHideDelay = "BarBoss_autoHideDelay"
        static let hideOnClickOutside = "BarBoss_hideOnClickOutside"
        static let hoverToReveal = "BarBoss_hoverToReveal"
        static let showAlwaysHiddenSection = "BarBoss_showAlwaysHiddenSection"
        static let menuBarIconStyle = "BarBoss_menuBarIconStyle"
        static let separatorStyle = "BarBoss_separatorStyle"
        static let hotkeyModifiers = "BarBoss_hotkeyModifiers"
        static let hotkeyKeyCode = "BarBoss_hotkeyKeyCode"
        static let sparkleAutoCheck = "SUEnableAutomaticChecks"
        static let sparkleAutoDownload = "SUAutomaticallyUpdate"
    }
    
    @Published public var isHidden: Bool {
        didSet { defaults.set(isHidden, forKey: Keys.isHidden) }
    }
    
    @Published public var hideMode: HideMode {
        didSet { defaults.set(hideMode.rawValue, forKey: Keys.hideMode) }
    }
    
    @Published public var autoHideDelay: Double {
        didSet { defaults.set(autoHideDelay, forKey: Keys.autoHideDelay) }
    }
    
    @Published public var hideOnClickOutside: Bool {
        didSet { defaults.set(hideOnClickOutside, forKey: Keys.hideOnClickOutside) }
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
    
    @Published public var launchAtLogin: Bool = false {
        didSet { setLaunchAtLogin(launchAtLogin) }
    }
    
    private init() {
        self.isHidden = defaults.object(forKey: Keys.isHidden) != nil ? defaults.bool(forKey: Keys.isHidden) : true
        
        let savedHideMode = defaults.string(forKey: Keys.hideMode) ?? HideMode.inline.rawValue
        self.hideMode = HideMode(rawValue: savedHideMode) ?? .inline
        
        self.autoHideDelay = defaults.object(forKey: Keys.autoHideDelay) != nil ? defaults.double(forKey: Keys.autoHideDelay) : 5.0
        self.hideOnClickOutside = defaults.object(forKey: Keys.hideOnClickOutside) != nil ? defaults.bool(forKey: Keys.hideOnClickOutside) : true
        self.hoverToReveal = defaults.bool(forKey: Keys.hoverToReveal)
        self.showAlwaysHiddenSection = defaults.bool(forKey: Keys.showAlwaysHiddenSection)
        
        let savedIconStyle = defaults.string(forKey: Keys.menuBarIconStyle) ?? MenuBarIconStyle.pug.rawValue
        self.menuBarIconStyle = MenuBarIconStyle(rawValue: savedIconStyle) ?? .pug
        
        let savedSeparatorStyle = defaults.string(forKey: Keys.separatorStyle) ?? SeparatorStyle.pipe.rawValue
        self.separatorStyle = SeparatorStyle(rawValue: savedSeparatorStyle) ?? .pipe
        
        // Default hotkey: Command + Shift + B (B = keyCode 11)
        self.hotkeyModifiers = defaults.object(forKey: Keys.hotkeyModifiers) != nil ? UInt(defaults.integer(forKey: Keys.hotkeyModifiers)) : (NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        self.hotkeyKeyCode = defaults.object(forKey: Keys.hotkeyKeyCode) != nil ? UInt16(defaults.integer(forKey: Keys.hotkeyKeyCode)) : 11
        
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
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
