import SwiftUI

public struct PermissionsTab: View {
    @ObservedObject var permissions = PermissionsManager.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("System Permissions")
                        .font(.headline)
                    Text("To hide and manage other applications' menu bar icons, macOS requires explicit user approval in System Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section {
                // Accessibility Permission
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: permissions.isAccessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(permissions.isAccessibilityGranted ? .green : .orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Enables BarBoss to manage menu bar icons and global shortcuts.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if permissions.isAccessibilityGranted {
                        Text("Granted")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                    } else {
                        Button(action: {
                            permissions.requestAccessibility()
                        }) {
                            Text("Grant Access")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Required Permissions")
            } footer: {
                Text("Note: After toggling a permission in System Settings, BarBoss will automatically detect it.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            permissions.checkPermissions()
        }
    }
}
