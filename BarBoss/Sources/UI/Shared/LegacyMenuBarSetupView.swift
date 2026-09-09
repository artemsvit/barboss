import SwiftUI

struct LegacyMenuBarSetupView: View {
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 12 : 16) {
            VStack(spacing: 5) {
                Text("Arrange Icons Manually")
                    .font(.system(size: compact ? 22 : 20, weight: .bold))
                Text("On macOS 14–26, BarBoss uses the menu bar’s native Command-drag arrangement.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                iconGroup(symbols: ["cloud.fill", "bolt.fill", "bell.fill"], label: "Hidden")

                Text("|")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.orange)

                iconGroup(symbols: ["wifi", "speaker.wave.2.fill"], label: "Always visible")

                Image(systemName: "sunglasses.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.orange)
                    .accessibilityLabel("BarBoss glasses")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.secondary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                instruction(1, "Click the BarBoss glasses to reveal the separator.")
                instruction(2, "Hold Command (⌘), then drag every icon you want hidden to the left of the | separator.")
                instruction(3, "Leave always-visible icons between the separator and the BarBoss glasses.")
                instruction(4, "Click the glasses to hide or reveal the group.")
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            }

            Label("No Accessibility permission is needed. macOS remembers your icon order.", systemImage: "checkmark.shield.fill")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(compact ? 22 : 14)
    }

    private func instruction(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(number)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 19, height: 19)
                .background(Color.orange)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func iconGroup(symbols: [String], label: String) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                ForEach(symbols, id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 18, height: 18)
                }
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}
