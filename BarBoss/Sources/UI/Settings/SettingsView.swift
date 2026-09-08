import SwiftUI
import Sparkle

public struct SettingsView: View {
    public init() {}
    
    public var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            MenuBarSettingsTab()
                .tabItem {
                    Label("Menu Bar", systemImage: "menubar.rectangle")
                }
            
            HotkeysSettingsTab()
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }
            
            AppearanceSettingsTab()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
            
            UpdatesSettingsTab()
                .tabItem {
                    Label("Updates", systemImage: "arrow.triangle.2.circlepath")
                }
            
            AboutSettingsTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 400)
        .padding(10)
    }
}

// MARK: - 1. General Tab
struct GeneralSettingsTab: View {
    @ObservedObject var prefs = Preferences.shared
    
    var body: some View {
        Form {
            Section {
                Toggle("Launch BarBoss at login", isOn: $prefs.launchAtLogin)
                    .help("Automatically starts BarBoss when you log in to your Mac.")
                
                Toggle("Hide on click outside", isOn: $prefs.hideOnClickOutside)
                    .help("Automatically hides menu items when you click elsewhere.")
                
                Toggle("Hover to reveal hidden items", isOn: $prefs.hoverToReveal)
                    .help("Move mouse cursor to the menu bar to automatically reveal items.")
            } header: {
                Text("Startup & Behavior").font(.headline)
            }
            
            Section {
                Picker("Auto-hide delay:", selection: $prefs.autoHideDelay) {
                    Text("Disabled").tag(0.0)
                    Text("3 seconds").tag(3.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("15 seconds").tag(15.0)
                    Text("30 seconds").tag(30.0)
                }
                .pickerStyle(.menu)
                .help("How long before revealed items are automatically collapsed.")
            } header: {
                Text("Timers").font(.headline)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 2. Menu Bar Tab
struct MenuBarSettingsTab: View {
    @ObservedObject var prefs = Preferences.shared
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "command")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.accentColor)
                            .padding(6)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text("How to Hide Menu Bar Icons")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("1.").fontWeight(.bold).foregroundColor(.accentColor)
                            Text("Hold the Command (⌘) key on your keyboard.")
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("2.").fontWeight(.bold).foregroundColor(.accentColor)
                            Text("Click and drag any menu bar icon to the LEFT of the separator ( | ).")
                        }
                        HStack(alignment: .top, spacing: 8) {
                            Text("3.").fontWeight(.bold).foregroundColor(.accentColor)
                            Text("Click the BarBoss icon (🕶️) or press ⌘⇧B to collapse or reveal!")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("How to Hide Icons").font(.headline)
            }
            
            Section {
                Picker("Hiding Method:", selection: $prefs.hideMode) {
                    ForEach(HideMode.allCases) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.title).font(.body)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                
                Text(prefs.hideMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            } header: {
                Text("Display Mode").font(.headline)
            }
            
            Section {
                Picker("Separator Symbol:", selection: $prefs.separatorStyle) {
                    ForEach(SeparatorStyle.allCases) { style in
                        Text("\(style.symbol)  \(style.title)").tag(style)
                    }
                }
                .pickerStyle(.menu)
                
                Toggle("Enable Always-Hidden section (‖)", isOn: $prefs.showAlwaysHiddenSection)
                    .help("Adds a second separator for items you want permanently hidden.")
            } header: {
                Text("Separators").font(.headline)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 3. Hotkeys Tab
struct HotkeysSettingsTab: View {
    @ObservedObject var prefs = Preferences.shared
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Toggle Hidden Items:")
                    Spacer()
                    Text("⌘ + ⇧ + B")
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                Text("Press this keyboard combination from any app to instantly toggle your hidden menu bar items.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Global Shortcuts").font(.headline)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 4. Appearance Tab
struct AppearanceSettingsTab: View {
    @ObservedObject var prefs = Preferences.shared
    
    var body: some View {
        Form {
            Section {
                Picker("Menu Bar Icon:", selection: $prefs.menuBarIconStyle) {
                    ForEach(MenuBarIconStyle.allCases) { style in
                        Label(style.title, systemImage: style.systemImageName)
                            .tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("BarBoss Icon Style").font(.headline)
            }
            
            Section {
                HStack(spacing: 20) {
                    VStack {
                        Image(systemName: prefs.menuBarIconStyle.systemImageName)
                            .font(.system(size: 24))
                            .frame(width: 50, height: 50)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        Text("Active Icon")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Live Preview")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("This icon appears in your macOS menu bar.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Preview").font(.headline)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 5. Updates Tab (Sparkle)
struct UpdatesSettingsTab: View {
    @ObservedObject var updateManager = UpdateManager.shared
    
    var body: some View {
        Form {
            Section {
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { updateManager.automaticallyChecksForUpdates },
                    set: { updateManager.automaticallyChecksForUpdates = $0 }
                ))
                
                Toggle("Automatically download new updates", isOn: Binding(
                    get: { updateManager.automaticallyDownloadsUpdates },
                    set: { updateManager.automaticallyDownloadsUpdates = $0 }
                ))
            } header: {
                Text("Automatic Updates").font(.headline)
            }
            
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Update Engine")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Powered by Sparkle framework.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let lastCheck = updateManager.lastUpdateCheckDate {
                            Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Check Now...") {
                        updateManager.checkForUpdates()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!updateManager.canCheckForUpdates)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Manual Check").font(.headline)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 6. About Tab
struct AboutSettingsTab: View {
    var body: some View {
        VStack(spacing: 16) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    .padding(.top, 10)
            } else {
                Image(systemName: "sunglasses.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.linearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(.top, 10)
            }
            
            VStack(spacing: 4) {
                Text("BarBoss")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0 (Build 1)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("The powerful, modern menu bar manager for macOS.\nOrganize, combine, and take control of your top bar icons.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Divider()
                .padding(.horizontal, 40)
            
            HStack(spacing: 20) {
                Link("Documentation", destination: URL(string: "https://barboss.app")!)
                    .font(.subheadline)
                
                Text("•").foregroundColor(.secondary)
                
                Link("Sparkle Project", destination: URL(string: "https://sparkle-project.org")!)
                    .font(.subheadline)
            }
            
            Text("Copyright © 2026 BarBoss. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
