import SwiftUI

public enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case permissions = 1
    case selectApps = 2
}

public struct OnboardingView: View {
    @State private var currentStep: OnboardingStep
    @ObservedObject var permissions = PermissionsManager.shared
    @ObservedObject var prefs = Preferences.shared
    @ObservedObject var scanner = MenuBarItemScanner.shared
    
    public var onFinish: (() -> Void)?
    
    public init(initialStep: OnboardingStep = .welcome, onFinish: (() -> Void)? = nil) {
        _currentStep = State(initialValue: initialStep)
        self.onFinish = onFinish
    }
    
    var shownItems: [DiscoveredMenuBarItem] {
        scanner.discoveredItems.filter { !prefs.isItemHidden($0.id) }
    }
    
    var hiddenItems: [DiscoveredMenuBarItem] {
        scanner.discoveredItems.filter { prefs.isItemHidden($0.id) }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Navigation & Progress Bar
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    Capsule()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.orange : Color.secondary.opacity(0.2))
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.25), value: currentStep)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            // Step Content Area
            ZStack {
                switch currentStep {
                case .welcome:
                    welcomeStepView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                case .permissions:
                    permissionsStepView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                case .selectApps:
                    selectAppsStepView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity.combined(with: .move(edge: .leading))
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentStep)
            
            // Bottom Action Bar
            VStack(spacing: 0) {
                Divider()
                    .opacity(0.4)
                
                HStack(alignment: .center) {
                    if currentStep != .welcome {
                        Button(action: {
                            if let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                                withAnimation {
                                    currentStep = prev
                                }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Back")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Spacer()
                            .frame(width: 60)
                    }
                    
                    Spacer()
                    
                    // Primary Action Button
                    if currentStep == .welcome {
                        Button(action: {
                            withAnimation {
                                currentStep = .permissions
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text("Get Started")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.regular)
                    } else if currentStep == .permissions {
                        Button(action: {
                            withAnimation {
                                currentStep = .selectApps
                            }
                        }) {
                            HStack(spacing: 6) {
                                Text(!MenuBarManager.supportsAutomaticItemSelection || permissions.isAccessibilityGranted ? "Continue" : "Skip for Now")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(!MenuBarManager.supportsAutomaticItemSelection || permissions.isAccessibilityGranted ? .orange : .secondary)
                        .controlSize(.regular)
                    } else {
                        Button(action: {
                            completeOnboarding()
                        }) {
                            HStack(spacing: 6) {
                                Text("Start Using BarBoss")
                                    .fontWeight(.semibold)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.regular)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .frame(width: 580, height: 530)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Step 1: Welcome
    private var welcomeStepView: some View {
        VStack(spacing: 14) {
            // App Icon Hero (Clean icon, no glowing aura, no stroke frame)
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                    .padding(.top, 6)
            } else {
                Image(systemName: "sunglasses.fill")
                    .font(.system(size: 42))
                    .foregroundColor(.orange)
                    .padding(.top, 6)
            }
            
            // Header Typography
            VStack(spacing: 4) {
                Text("Welcome to BarBoss")
                    .font(.system(size: 22, weight: .bold))
                
                Text("The minimal menu bar manager for macOS.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            // Feature List Cards
            VStack(spacing: 8) {
                featureCard(
                    icon: "eye.slash.fill",
                    color: .orange,
                    title: "Instant Menu Bar Declutter",
                    description: "Collapse noisy status icons behind a sleek glasses icon with a single click."
                )
                
                featureCard(
                    icon: "keyboard.fill",
                    color: .indigo,
                    title: "Customizable Global Shortcut",
                    description: "Summon or hide your icons instantly from any app using a keyboard shortcut."
                )
                
                featureCard(
                    icon: "lock.shield.fill",
                    color: .green,
                    title: "100% Private & Native",
                    description: "Engineered for macOS. Zero screen recording, zero tracking, effortless speed."
                )
            }
            .padding(.horizontal, 28)
            .padding(.top, 4)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Step 2: Permissions
    @ViewBuilder
    private var permissionsStepView: some View {
        if MenuBarManager.supportsAutomaticItemSelection {
            automaticPermissionsStepView
        } else {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.green)
                }

                VStack(spacing: 6) {
                    Text("No Permissions Needed")
                        .font(.system(size: 22, weight: .bold))
                    Text("On macOS 14–26, BarBoss uses the menu bar’s built-in Command-drag arrangement. It does not need Accessibility access.")
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 38)
                }

                Label("Next, you’ll arrange the icons you want BarBoss to hide.", systemImage: "command")
                    .font(.system(size: 12, weight: .medium))
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 32)

                Spacer(minLength: 0)
            }
            .padding(.top, 18)
        }
    }

    private var automaticPermissionsStepView: some View {
        VStack(spacing: 14) {
            // Permissions Icon Hero (Clean, no glow)
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 68, height: 68)
                
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
            }
            .padding(.top, 6)
            
            // Header Typography
            VStack(spacing: 4) {
                Text("Accessibility Permission")
                    .font(.system(size: 22, weight: .bold))
                
                Text("BarBoss only needs Accessibility access to interact with macOS MenuBarAgent.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            
            // Status & Action Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: permissions.isAccessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(permissions.isAccessibilityGranted ? .green : .orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility Access")
                            .font(.system(size: 13, weight: .semibold))
                        Text(permissions.isAccessibilityGranted ? "Granted — BarBoss is fully authorized." : "Click below to grant access in System Settings.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if permissions.isAccessibilityGranted {
                        Text("Enabled")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                    } else {
                        Button(action: {
                            permissions.requestAccessibility()
                        }) {
                            Text("Open Settings")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.small)
                    }
                }
                
                Divider()
                    .opacity(0.6)
                
                // Instructions
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to enable:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .top, spacing: 6) {
                        Text("1.")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                        Text("Click **Open Settings** above.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 6) {
                        Text("2.")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                        Text("In **Privacy & Security → Accessibility**, turn on **BarBoss**.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(alignment: .top, spacing: 6) {
                        Text("3.")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                        Text("BarBoss detects the change instantly — no restart required.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 28)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .onAppear {
            permissions.checkPermissions()
            permissions.startPolling()
        }
    }
    
    // MARK: - Step 3: Choose Apps to Hide (Aligned with Settings & Onboarding style)
    @ViewBuilder
    private var selectAppsStepView: some View {
        if MenuBarManager.supportsAutomaticItemSelection {
            automaticSelectAppsStepView
        } else {
            LegacyMenuBarSetupView(compact: true)
        }
    }

    private var automaticSelectAppsStepView: some View {
        VStack(spacing: 10) {
            // Header Typography
            VStack(spacing: 4) {
                Text("Choose Apps to Hide")
                    .font(.system(size: 22, weight: .bold))
                
                Text("Select which menu bar icons you want BarBoss to hide behind your glasses.")
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)
            
            // Sub-header
            Text("Left panel: shown in menu bar. Right panel: hidden in BarBoss.")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
            
            // 2-Sided Panel
            HStack(spacing: 12) {
                // LEFT: Shown in Menu Bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Shown in Menu Bar")
                            .font(.system(size: 12, weight: .semibold))
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
                
                // RIGHT: Hidden in BarBoss
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Hidden in BarBoss")
                            .font(.system(size: 12, weight: .semibold))
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
                                VStack(spacing: 4) {
                                    Text("No items hidden yet")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("Click \"Hide →\" to add apps here.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
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
            .frame(height: 300)
            .padding(.horizontal, 22)
            
            // Footer Tip
            Text("Tip: Click an arrow to move an app between Shown and Hidden.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .onAppear {
            scanner.scanItems()
        }
    }
    
    // MARK: - Reusable UI Components
    private func featureCard(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(description)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "BarBoss_hasCompletedOnboarding")
        permissions.stopPolling()
        onFinish?()
    }
}
