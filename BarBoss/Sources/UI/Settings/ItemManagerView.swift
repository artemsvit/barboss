import SwiftUI

public struct ItemManagerView: View {
    @ObservedObject var scanner = MenuBarItemScanner.shared
    @ObservedObject var prefs = Preferences.shared
    @ObservedObject var permissions = PermissionsManager.shared
    
    public init() {}
    
    var shownItems: [DiscoveredMenuBarItem] {
        scanner.discoveredItems.filter { !prefs.isItemHidden($0.id) }
    }
    
    var hiddenItems: [DiscoveredMenuBarItem] {
        scanner.discoveredItems.filter { prefs.isItemHidden($0.id) }
    }
    
    public var body: some View {
        VStack(spacing: 10) {
            // Permissions Warning Banner if not granted
            if !permissions.hasAllPermissions {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility Permission Required")
                            .font(.system(size: 11, weight: .bold))
                        Text("Accessibility is needed to manage and toggle your menu bar icons.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        permissions.requestAccessibility()
                    }) {
                        Text("Grant Permission")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 4)
            }
            
            // 2-Sided Panel
            HStack(spacing: 14) {
                // LEFT SIDE: Shown in Menu Bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Shown in Menu Bar")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text("\(shownItems.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            if shownItems.isEmpty {
                                Text("No items shown")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 40)
                            } else {
                                ForEach(shownItems) { item in
                                    ItemRow(item: item, isHiddenList: false) {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            prefs.hideItem(item.id)
                                            MenuBarManager.shared.updateItemStates()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(6)
                    }
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                }
                
                // RIGHT SIDE: Hidden in BarBoss
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Hidden in BarBoss")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text("\(hiddenItems.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            if hiddenItems.isEmpty {
                                VStack(spacing: 6) {
                                    Text("No items hidden yet")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("Click \"Hide →\" on any app on the left to hide it.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 40)
                            } else {
                                ForEach(hiddenItems) { item in
                                    ItemRow(item: item, isHiddenList: true) {
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            prefs.showItem(item.id)
                                            MenuBarManager.shared.updateItemStates()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(6)
                    }
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                }
            }
            .frame(height: 320)
            
            // Footer Tip
            Text("Tip: Click an arrow to move an app between Shown and Hidden.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
        .padding(10)
        .onAppear {
            scanner.scanItems()
        }
    }
}

struct ItemRow: View {
    let item: DiscoveredMenuBarItem
    let isHiddenList: Bool
    let onTransfer: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "app.fill")
                    .frame(width: 20, height: 20)
                    .foregroundColor(.secondary)
            }
            
            Text(item.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            
            Spacer()
            
            Button(action: onTransfer) {
                HStack(spacing: 3) {
                    if isHiddenList {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Show")
                            .font(.system(size: 10, weight: .semibold))
                    } else {
                        Text("Hide")
                            .font(.system(size: 10, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isHiddenList ? Color.blue.opacity(0.18) : Color.secondary.opacity(0.15))
                .foregroundColor(isHiddenList ? .blue : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovered ? Color.secondary.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
