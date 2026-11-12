import ActivityKit
import SwiftUI
import UIKit

/// One simulated upload, mirrored into a Live Activity.
@MainActor
final class UploadJob: ObservableObject, Identifiable {
    let id = UUID()
    let attributes: UploadActivityAttributes
    /// When true the job walks itself through every state (queued → pause → fail → retry → done).
    let isTour: Bool

    @Published private(set) var state: UploadState

    private var activity: Activity<UploadActivityAttributes>?
    private var timer: Timer?
    private var lastTick = Date()
    private var lastPush = Date.distantPast
    private var pushedPhase: UploadPhase?
    private var baseSpeed: Double
    private var phaseEndsAt: Date?
    private var tourPausedOnce = false
    private var tourFailedOnce = false
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    init(attributes: UploadActivityAttributes, isTour: Bool, uploadSeconds: Double = 16) {
        self.attributes = attributes
        self.isTour = isTour
        self.baseSpeed = Double(attributes.fileSize) / uploadSeconds
        self.state = UploadState(phase: .queued, progress: 0, bytesSent: 0, bytesPerSecond: 0,
                                 secondsRemaining: nil, message: "Queued – starts shortly")
    }

    // MARK: Lifecycle

    func start() {
        do {
            activity = try Activity.request(attributes: attributes,
                                            content: ActivityContent(state: state, staleDate: nil),
                                            pushType: nil)
        } catch {
            print("Live Activity request failed: \(error)")
        }
        pushedPhase = state.phase
        lastPush = Date()
        phaseEndsAt = Date().addingTimeInterval(2)
        beginBackgroundTime()
        startTimer()
    }

    func pause() { setPhase(.paused) }
    func resume() { setPhase(.uploading) }

    func fail(_ message: String = "Network connection lost") {
        state.message = message
        setPhase(.failed)
    }

    func retry() {
        state.message = "Reconnecting…"
        setPhase(.retrying)
        phaseEndsAt = Date().addingTimeInterval(2)
    }

    func complete() {
        state.progress = 1
        state.bytesSent = attributes.fileSize
        setPhase(.completed)
        finish(after: 4, policy: .after(Date().addingTimeInterval(15 * 60)))
    }

    func cancel() {
        setPhase(.cancelled)
        finish(after: 2, policy: .immediate)
    }

    /// Scrub progress from the UI (works in any non-terminal phase).
    func scrub(to progress: Double) {
        guard !state.phase.isTerminal else { return }
        state.progress = progress
        state.bytesSent = Int64(Double(attributes.fileSize) * progress)
        push(force: false)
    }

    /// Freeze the job in a specific phase – handy for inspecting each look.
    func pin(_ phase: UploadPhase) {
        state.message = nil
        switch phase {
        case .completed: complete()
        case .cancelled: cancel()
        case .failed: fail()
        case .retrying: retry()
        default: setPhase(phase)
        }
        // Hold timed phases (queued / retrying) instead of auto-advancing.
        phaseEndsAt = .distantFuture
    }

    // MARK: Simulation

    private func startTimer() {
        lastTick = Date()
        let t = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now

        switch state.phase {
        case .queued:
            if let end = phaseEndsAt, now >= end { state.message = nil; setPhase(.uploading) }

        case .retrying:
            if let end = phaseEndsAt, now >= end { state.message = nil; setPhase(.uploading) }

        case .failed:
            if isTour, let end = phaseEndsAt, now >= end { retry() }

        case .uploading:
            let speed = baseSpeed * Double.random(in: 0.65...1.35)
            state.bytesPerSecond = speed
            state.bytesSent = min(attributes.fileSize, state.bytesSent + Int64(speed * dt))
            state.progress = Double(state.bytesSent) / Double(attributes.fileSize)
            state.secondsRemaining = Int((Double(attributes.fileSize - state.bytesSent) / baseSpeed).rounded(.up))

            if state.bytesSent >= attributes.fileSize { complete(); return }
            if isTour { runTourScript(now: now) }
            push(force: false)

        case .paused:
            if isTour, let end = phaseEndsAt, now >= end { resume() }

        case .completed, .cancelled:
            break
        }
    }

    private func runTourScript(now: Date) {
        if !tourPausedOnce, state.progress >= 0.3 {
            tourPausedOnce = true
            pause()
            phaseEndsAt = now.addingTimeInterval(3)
        } else if !tourFailedOnce, state.progress >= 0.62 {
            tourFailedOnce = true
            fail()
            phaseEndsAt = now.addingTimeInterval(3)
        }
    }

    private func setPhase(_ phase: UploadPhase) {
        guard !state.phase.isTerminal else { return }
        state.phase = phase
        if phase != .uploading {
            state.bytesPerSecond = 0
            state.secondsRemaining = nil
        }
        push(force: true)
    }

    /// ActivityKit coalesces rapid updates, so only push ~1/s unless the phase changed.
    private func push(force: Bool) {
        let now = Date()
        guard force || state.phase != pushedPhase || now.timeIntervalSince(lastPush) >= 1 else { return }
        lastPush = now
        pushedPhase = state.phase
        let content = ActivityContent(state: state, staleDate: nil)
        Task { await activity?.update(content) }
    }

    private func finish(after delay: TimeInterval, policy: ActivityUIDismissalPolicy) {
        timer?.invalidate()
        timer = nil
        let content = ActivityContent(state: state, staleDate: nil)
        Task {
            try? await Task.sleep(for: .seconds(delay))
            await activity?.end(content, dismissalPolicy: policy)
            endBackgroundTime()
            UploadCenter.shared.remove(self)
        }
    }

    // The simulated upload runs on an in-process timer; ask for a little background
    // time so the island keeps moving after you swipe home. (A real app would use a
    // background URLSession and/or ActivityKit push updates.)
    private func beginBackgroundTime() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "upload-sim") { [weak self] in
            self?.endBackgroundTime()
        }
    }

    private func endBackgroundTime() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}

/// Owns all running uploads.
@MainActor
final class UploadCenter: ObservableObject {
    static let shared = UploadCenter()

    @Published private(set) var jobs: [UploadJob] = []
    @Published private(set) var activitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

    private static let samples: [UploadActivityAttributes] = [
        .init(fileName: "Vacation-4K.mov", fileSize: 486_000_000, fileSymbol: "film", destination: "iCloud Drive"),
        .init(fileName: "Q4 Report.pdf", fileSize: 18_400_000, fileSymbol: "doc.richtext", destination: "Team Drive"),
        .init(fileName: "Photos (124)", fileSize: 912_000_000, fileSymbol: "photo.stack", destination: "Google Photos"),
        .init(fileName: "Podcast-Ep42.wav", fileSize: 240_000_000, fileSymbol: "waveform", destination: "Dropbox"),
        .init(fileName: "Backup.zip", fileSize: 1_300_000_000, fileSymbol: "archivebox", destination: "S3 bucket"),
    ]
    private var nextSample = 0

    private init() {}

    func refreshAuthorization() {
        activitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    }

    @discardableResult
    func startUpload(tour: Bool) -> UploadJob {
        let attributes = Self.samples[nextSample % Self.samples.count]
        nextSample += 1
        let job = UploadJob(attributes: attributes, isTour: tour, uploadSeconds: tour ? 16 : 24)
        jobs.append(job)
        job.start()
        return job
    }

    func remove(_ job: UploadJob) {
        jobs.removeAll { $0.id == job.id }
    }

    /// Activities survive app relaunches; clear leftovers from a previous run.
    func endStaleActivities() async {
        for activity in Activity<UploadActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Launch arguments for hands-free demos / screenshots:
    ///   -autostart N   start N tour uploads (2+ shows the minimal ring)
    ///   -pin <phase>   start one upload frozen in that phase at ~42 %
    func handleLaunchArguments() {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: "autostart")
        for _ in 0..<count { startUpload(tour: true) }

        if let raw = defaults.string(forKey: "pin"), let phase = UploadPhase(rawValue: raw) {
            let job = startUpload(tour: false)
            job.scrub(to: 0.42)
            job.pin(phase)
        }
    }
}
