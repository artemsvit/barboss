import Foundation
import Sparkle
import Combine

public final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    public static let shared = UpdateManager()
    
    private var updaterController: SPUStandardUpdaterController?
    
    @Published public var canCheckForUpdates: Bool = false
    @Published public var lastUpdateCheckDate: Date? = nil
    
    public override init() {
        super.init()
        setupSparkle()
    }
    
    private func setupSparkle() {
        // Initialize standard updater controller
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        self.updaterController = controller
        self.canCheckForUpdates = controller.updater.canCheckForUpdates
        self.lastUpdateCheckDate = controller.updater.lastUpdateCheckDate
        
        // Observe canCheckForUpdates
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
        
        controller.updater.publisher(for: \.lastUpdateCheckDate)
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastUpdateCheckDate)
    }
    
    public func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
    
    public var automaticallyChecksForUpdates: Bool {
        get { updaterController?.updater.automaticallyChecksForUpdates ?? true }
        set { updaterController?.updater.automaticallyChecksForUpdates = newValue }
    }
    
    public var automaticallyDownloadsUpdates: Bool {
        get { updaterController?.updater.automaticallyDownloadsUpdates ?? false }
        set { updaterController?.updater.automaticallyDownloadsUpdates = newValue }
    }
    
    public var updateCheckInterval: TimeInterval {
        get { updaterController?.updater.updateCheckInterval ?? 86400 }
        set { updaterController?.updater.updateCheckInterval = newValue }
    }
    
    public var feedURL: URL? {
        updaterController?.updater.feedURL
    }
}
