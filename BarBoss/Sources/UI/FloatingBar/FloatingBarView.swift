import SwiftUI

public struct FloatingBarView: View {
    @ObservedObject var preferences = Preferences.shared
    @ObservedObject var scanner = MenuBarItemScanner.shared
    @State private var searchText = ""
    public var onClose: () -> Void
    public var onOpenSettings: () -> Void
    
    public init(onClose: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.onClose = onClose
        self.onOpenSettings = onOpenSettings
    }
    
    var hiddenItems: [DiscoveredMenuBarItem] {
        let items = scanner.discoveredItems.filter { preferences.isItemHidden($0.id) }
        if searchText.isEmpty { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            // Header / Search row
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12, weight: .medium))
                
                TextField("Search hidden items...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Manage Hidden Items in Settings")
                
                Button(action: onClose) {
                    Image(systemName: "chevron.up")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Hide BarBoss Bar")
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            
            Divider()
                .opacity(0.3)
            
            // Bar Content: Real Hidden Items
            if hiddenItems.isEmpty {
                VStack(spacing: 6) {
                    Text("No hidden items configured")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Button(action: onOpenSettings) {
                        Text("Configure in Settings")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(hiddenItems) { item in
                            HiddenAppButton(item: item) {
                                scanner.activateApp(bundleIdentifier: item.bundleIdentifier)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)
                }
            }
        }
        .padding(6)
        .frame(minWidth: 320, maxWidth: 460)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
        )
        .onAppear {
            scanner.scanItems()
        }
    }
}

struct HiddenAppButton: View {
    let item: DiscoveredMenuBarItem
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 26, height: 26)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 18))
                        .frame(width: 26, height: 26)
                }
                
                Text(item.name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isHovered ? .primary : .secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 54)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(isHovered ? Color.white.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("Open \(item.name)")
    }
}
