import AppKit
import ApplicationServices
import Combine

public final class PermissionsManager: ObservableObject {
    public static let shared = PermissionsManager()
    
    @Published public private(set) var isAccessibilityGranted: Bool = false
    @Published public private(set) var isScreenRecordingGranted: Bool = false
    
    private var checkTimer: Timer?
    
    public var hasAllPermissions: Bool {
        isAccessibilityGranted
    }
    
    private init() {
        checkPermissions()
        startPolling()
    }
    
    public func checkPermissions() {
        let ax = AXIsProcessTrusted()
        let sr = CGPreflightScreenCaptureAccess()
        
        if ax != isAccessibilityGranted {
            isAccessibilityGranted = ax
        }
        if sr != isScreenRecordingGranted {
            isScreenRecordingGranted = sr
        }
    }
    
    public func startPolling() {
        stopPolling()
        // Poll every 1.5s so when user toggles permission in System Settings it updates live
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkPermissions()
            }
        }
    }
    
    public func stopPolling() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    public func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openAccessibilitySettings()
    }
    
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
        openScreenRecordingSettings()
    }
    
    public func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
