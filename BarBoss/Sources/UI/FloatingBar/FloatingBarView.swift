import SwiftUI

public struct FloatingBarView: View {
    @ObservedObject var preferences = Preferences.shared
    @State private var searchText = ""
    public var onClose: () -> Void
    public var onOpenSettings: () -> Void
    
    public init(onClose: @escaping () -> Void, onOpenSettings: @escaping () -> Void) {
        self.onClose = onClose
        self.onOpenSettings = onOpenSettings
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // Header / Search row
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13, weight: .medium))
                
                TextField("Search menu bar items...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Open BarBoss Settings")
                
                Button(action: onClose) {
                    Image(systemName: "chevron.up")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Hide BarBoss Bar")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            Divider()
                .opacity(0.3)
            
            // Bar Content: Quick Actions & Status Tools
            HStack(spacing: 16) {
                QuickItemButton(icon: "wifi", label: "Network", action: {})
                QuickItemButton(icon: "battery.100", label: "Power", action: {})
                QuickItemButton(icon: "speaker.wave.2.fill", label: "Sound", action: {})
                QuickItemButton(icon: "moon.fill", label: "Focus", action: {})
                QuickItemButton(icon: "display", label: "Display", action: {})
                QuickItemButton(icon: "lock.shield", label: "Security", action: {})
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .padding(6)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.28), radius: 20, x: 0, y: 10)
        )
    }
}

struct QuickItemButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 32, height: 32)
                    .background(isHovered ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                Text(label)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
