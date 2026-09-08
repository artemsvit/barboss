import SwiftUI
import AppKit

public struct ShortcutRecorderView: View {
    @ObservedObject var prefs = Preferences.shared
    @State private var isRecording = false
    @State private var localMonitor: Any?
    
    public init() {}
    
    private var currentCombo: KeyCombo {
        KeyCombo(
            keyCode: prefs.hotkeyKeyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: prefs.hotkeyModifiers)
        )
    }
    
    @State private var isHovering = false
    
    private var isCustomShortcut: Bool {
        prefs.hotkeyKeyCode != 11 || prefs.hotkeyModifiers != (NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Interactive Shortcut Keycap / Recorder
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                HStack(spacing: 6) {
                    if isRecording {
                        Image(systemName: "record.circle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 11))
                        Text("Press keys on keyboard...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    } else {
                        Image(systemName: "keyboard")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                        
                        Text(currentCombo.displayString)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isRecording ? Color.orange.opacity(0.12) : (isHovering ? Color(NSColor.controlBackgroundColor) : Color(NSColor.controlBackgroundColor).opacity(0.6)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isRecording ? Color.orange : (isHovering ? Color.secondary.opacity(0.4) : Color.secondary.opacity(0.2)), lineWidth: isRecording ? 1.5 : 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .help(isRecording ? "Press keys on your keyboard, or press Esc to cancel" : "Click to record a new keyboard shortcut")
            
            // Action button (Cancel during recording, or Reset when customized)
            if isRecording {
                Button("Cancel") {
                    stopRecording()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if isCustomShortcut {
                Button(action: {
                    resetToDefault()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Reset")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Reset to default shortcut (⇧⌘B)")
            }
        }
        .onDisappear {
            stopRecording()
        }
    }
    
    private func startRecording() {
        stopRecording()
        isRecording = true
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Escape cancels recording
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            
            let relevantModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            
            // Require at least one modifier key
            guard !relevantModifiers.isEmpty else {
                NSSound.beep()
                return nil
            }
            
            // Save newly recorded shortcut
            prefs.hotkeyModifiers = UInt(relevantModifiers.rawValue)
            prefs.hotkeyKeyCode = event.keyCode
            
            // Re-arm hotkey manager
            HotkeyManager.shared.start()
            
            stopRecording()
            return nil
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    private func resetToDefault() {
        prefs.hotkeyModifiers = UInt(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        prefs.hotkeyKeyCode = 11 // 'B'
        HotkeyManager.shared.start()
    }
}
