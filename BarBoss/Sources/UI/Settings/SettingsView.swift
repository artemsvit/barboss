import SwiftUI
import Sparkle

public struct SettingsView: View {
    public init() {}
    
    public var body: some View {
        TabView {
            ItemManagerView()
                .tabItem {
                    Label("Menu Bar Items", systemImage: "square.split.2x1")
                }
            
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            HotkeysSettingsTab()
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
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
        .frame(width: 620, height: 420)
        .padding(10)
    }
}

// MARK: - General Tab
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
                Text("Startup and Behavior").font(.headline)
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

// MARK: - Hotkeys Tab
struct HotkeysSettingsTab: View {
    @ObservedObject var prefs = Preferences.shared
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Toggle Hidden Items:")
                    Spacer()
                    Text("Command + Shift + B")
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

// MARK: - Updates Tab (Sparkle)
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

// MARK: - About Tab
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
            
            Text("The minimal menu bar manager for macOS.\nOrganize, combine, and take control of your top bar icons.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Divider()
                .padding(.horizontal, 40)
            
            HStack(spacing: 20) {
                Link("Documentation", destination: URL(string: "https://barboss.artsvit.com")!)
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
