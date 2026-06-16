import Foundation
import UIKit
import AVFoundation
import os.log

/// BackgroundService - keeps the app alive in the background.
///
/// iOS has no concept of an Android-style foreground service. Instead this
/// uses `UIApplication` background tasks to extend background execution, and
/// (optionally) a silent audio loop. Long-lived BLE background execution comes
/// from the `bluetooth-central` UIBackgroundMode declared in the host app's
/// Info.plist; this service complements that by holding a background task while
/// transitioning in and out of the background.
class BackgroundService: NSObject {

    static let shared = BackgroundService()

    private let log = OSLog(subsystem: "com.sparkleo.flutter_blue_background", category: "BackgroundService")

    private var isRunning = false
    private var audioPlayer: AVAudioPlayer?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    private override init() {
        super.init()
    }

    /// Start the background service.
    func start() {
        guard !isRunning else {
            os_log("BackgroundService already running", log: log, type: .info)
            return
        }

        isRunning = true
        os_log("Starting BackgroundService", log: log, type: .info)

        setupBackgroundTaskHandling()

        // Optional: uncomment to enable silent audio keep-alive (see warning below).
        // setupSilentAudio()

        os_log("BackgroundService started", log: log, type: .info)
    }

    /// Stop the background service.
    func stop() {
        guard isRunning else { return }

        isRunning = false
        os_log("Stopping BackgroundService", log: log, type: .info)

        NotificationCenter.default.removeObserver(self)
        stopSilentAudio()
        endBackgroundTask()

        os_log("BackgroundService stopped", log: log, type: .info)
    }

    // MARK: - Background Task Handling

    private func setupBackgroundTaskHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appDidEnterBackground() {
        os_log("Entered background", log: log, type: .info)
        startBackgroundTask()
    }

    @objc private func appWillEnterForeground() {
        os_log("Entering foreground", log: log, type: .info)
        endBackgroundTask()
    }

    private func startBackgroundTask() {
        endBackgroundTask() // End any existing task first.

        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            guard let self = self else { return }
            os_log("Background task expiring", log: self.log, type: .info)
            self.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    // MARK: - Silent Audio (Optional - use with caution)

    /// Setup silent audio to keep the app alive.
    ///
    /// WARNING: this approach is controversial and may be rejected by App Store
    /// review. Only use it if you have a valid, documented use case. It requires
    /// the `audio` UIBackgroundMode and a bundled `silence.mp3` resource.
    private func setupSilentAudio() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)

            guard let soundURL = Bundle.main.url(forResource: "silence", withExtension: "mp3") else {
                os_log("Silent audio file not found", log: log, type: .error)
                return
            }

            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.numberOfLoops = -1 // Infinite loop
            audioPlayer?.volume = 0.01 // Very low volume
            audioPlayer?.play()

            os_log("Silent audio started", log: log, type: .info)
        } catch {
            os_log("Failed to setup silent audio: %{public}@", log: log, type: .error, error.localizedDescription)
        }
    }

    private func stopSilentAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    // MARK: - Status

    func isServiceRunning() -> Bool {
        return isRunning
    }

    func getServiceStatus() -> [String: Any] {
        return [
            "isRunning": isRunning,
            "backgroundTimeRemaining": UIApplication.shared.backgroundTimeRemaining
        ]
    }
}
