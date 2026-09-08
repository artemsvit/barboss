import AppKit
import Darwin

final class AgentDelegate: NSObject, NSApplicationDelegate {
    private var parentMonitor: Timer?
    private var parentPID: pid_t?
    private var assertion: NSObject?
    private var configuration: NSObject?
    private var frameworkHandle: UnsafeMutableRawPointer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
        parentPID = Self.parentPID(from: CommandLine.arguments)

        // Monitor parent process so helper never lingers if BarBoss exits
        parentMonitor = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let parentPID = self?.parentPID, parentPID > 1 else { return }
            if kill(parentPID, 0) != 0 && errno == ESRCH {
                self?.cleanupAndExit()
            }
        }

        signal(SIGTERM) { _ in
            NSApp.terminate(nil)
        }

        activateAssertion()
    }

    private func activateAssertion() {
        let hiddenBundleIDs = Self.hiddenBundleIDs(from: CommandLine.arguments)
        guard loadFramework() else {
            print("BarBossVisibilityAgent: Failed to load MenuBarClientCore framework")
            return
        }

        var allowedBundleIdentifiers = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        )
        allowedBundleIdentifiers.subtract(hiddenBundleIDs)
        allowedBundleIdentifiers.formUnion([
            "com.barboss.app", "BarBoss"
        ])

        guard let configurationClass = NSClassFromString("MBAssessmentModeConfiguration"),
              let assertionClass = NSClassFromString("MBAssessmentModeAssertion"),
              let rawConfiguration = class_createInstance(configurationClass, 0) as? NSObject,
              let rawAssertion = class_createInstance(assertionClass, 0) as? NSObject else { return }

        let configurationSelector = NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:")
        let assertionInitSelector = NSSelectorFromString("init")
        let activateSelector = NSSelectorFromString("activateWithConfiguration:completionHandler:")

        guard let config = rawConfiguration
            .perform(
                configurationSelector,
                with: Array(0...8).map(NSNumber.init(value:)) as NSArray,
                with: Array(allowedBundleIdentifiers).sorted() as NSArray
            )?
            .takeUnretainedValue() as? NSObject,
              let assertObj = rawAssertion
                .perform(assertionInitSelector)?
                .takeUnretainedValue() as? NSObject else { return }

        self.configuration = config
        self.assertion = assertObj

        let completion: @convention(block) () -> Void = {}
        let completionObject: AnyObject = unsafeBitCast(completion, to: AnyObject.self)
        assertObj.perform(activateSelector, with: config, with: completionObject)
    }

    func applicationWillTerminate(_ notification: Notification) {
        cleanup()
    }

    private func cleanup() {
        parentMonitor?.invalidate()
        parentMonitor = nil
        if let assertion {
            let selector = NSSelectorFromString("invalidate")
            if assertion.responds(to: selector) {
                assertion.perform(selector)
            }
        }
        assertion = nil
        configuration = nil
        if let frameworkHandle {
            dlclose(frameworkHandle)
            self.frameworkHandle = nil
        }
    }

    private func cleanupAndExit() {
        cleanup()
        exit(0)
    }

    private func loadFramework() -> Bool {
        if frameworkHandle != nil { return true }
        frameworkHandle = dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore", RTLD_NOW | RTLD_LOCAL)
        return frameworkHandle != nil
    }

    private static func parentPID(from arguments: [String]) -> pid_t? {
        guard let index = arguments.firstIndex(of: "--parent-pid"), index + 1 < arguments.count else {
            return nil
        }
        return pid_t(arguments[index + 1])
    }

    private static func hiddenBundleIDs(from arguments: [String]) -> Set<String> {
        guard let index = arguments.firstIndex(of: "--hide"), index + 1 < arguments.count else {
            return []
        }
        let list = arguments[index + 1].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return Set(list.filter { !$0.isEmpty })
    }
}

let application = NSApplication.shared
let delegate = AgentDelegate()
application.delegate = delegate
application.run()
