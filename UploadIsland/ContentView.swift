import SwiftUI

struct ContentView: View {
    @ObservedObject private var center = UploadCenter.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                actions
                if !center.jobs.isEmpty {
                    section("Active uploads") {
                        ForEach(center.jobs) { JobCard(job: $0) }
                    }
                }
                PresentationGallery(job: center.jobs.first)
                StateStrip()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(Color(white: 0.06).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { center.refreshAuthorization() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Upload Island")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Simulated uploads mirrored into Live Activities. Progress traces the edge of the Dynamic Island.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !center.activitiesEnabled {
                Label("Live Activities are turned off for this app in Settings.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(UploadPhase.failed.tint)
                    .padding(.top, 4)
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    center.startUpload(tour: true)
                } label: {
                    Label("Run demo tour", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(UploadPhase.uploading.tint)

                Button {
                    center.startUpload(tour: false)
                } label: {
                    Label("Manual upload", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
            .foregroundStyle(.white)

            Text("The tour walks through waiting → uploading → paused → failed → retrying → uploaded. Swipe home to watch the real island; start two uploads to see the minimal ring.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Job card

private struct JobCard: View {
    @ObservedObject var job: UploadJob

    var body: some View {
        let s = job.state
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: job.attributes.fileSymbol)
                    .foregroundStyle(s.phase.tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(job.attributes.fileName).font(.headline)
                    Text(UploadFormat.detail(s, job.attributes))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if job.isTour {
                    Text("TOUR").font(.caption2.weight(.heavy)).foregroundStyle(.secondary)
                }
                Text(s.phase.title)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(s.phase.tint.opacity(0.2)))
                    .foregroundStyle(s.phase.tint)
            }

            Slider(value: Binding(get: { job.state.progress }, set: { job.scrub(to: $0) }), in: 0...1)
                .tint(s.phase.tint)
                .disabled(s.phase.isTerminal)

            HStack(spacing: 8) {
                switch s.phase {
                case .uploading:
                    control("Pause", "pause.fill") { job.pause() }
                    control("Fail", "wifi.slash") { job.fail() }
                case .paused:
                    control("Resume", "play.fill") { job.resume() }
                case .failed:
                    control("Retry", "arrow.clockwise") { job.retry() }
                case .queued, .retrying, .completed, .cancelled:
                    EmptyView()
                }
                if !s.phase.isTerminal {
                    control("Finish", "checkmark") { job.complete() }
                    control("Cancel", "xmark") { job.cancel() }
                }
            }

            Menu {
                ForEach(UploadPhase.allCases, id: \.self) { phase in
                    Button(phase.title) { job.pin(phase) }
                }
            } label: {
                Label("Pin a state", systemImage: "pin")
                    .font(.footnote.weight(.semibold))
            }
            .disabled(s.phase.isTerminal)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(white: 0.11)))
    }

    private func control(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.footnote.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .tint(.white)
    }
}

// MARK: - Gallery

private enum Presentation: String, CaseIterable, Identifiable {
    case compact = "Compact", minimal = "Minimal", expanded = "Expanded", lockScreen = "Lock Screen"
    var id: String { rawValue }
}

private struct PresentationGallery: View {
    var job: UploadJob?
    @State private var presentation: Presentation = .compact

    var body: some View {
        section("Presentations") {
            Picker("Presentation", selection: $presentation) {
                ForEach(Presentation.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Group {
                if let job {
                    JobPresentation(job: job, presentation: presentation)
                } else {
                    PresentationPreview(attributes: sampleAttributes, state: sampleState, presentation: presentation)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.16)))
        }
    }
}

private struct JobPresentation: View {
    @ObservedObject var job: UploadJob
    var presentation: Presentation

    var body: some View {
        PresentationPreview(attributes: job.attributes, state: job.state, presentation: presentation)
    }
}

private struct PresentationPreview: View {
    var attributes: UploadActivityAttributes
    var state: UploadState
    var presentation: Presentation

    var body: some View {
        switch presentation {
        case .compact:
            VStack(spacing: 14) {
                ContinuousCompactMock(attributes: attributes, state: state)
                caption("Concept – one continuous ring")
                SplitCompactMock(attributes: attributes, state: state)
                caption("On device – trailing fills 0–50 %, leading 50–100 %")
            }
        case .minimal:
            VStack(spacing: 14) {
                MinimalMock(state: state)
                caption("Shown when 2+ activities run – ring on the circle's edge")
            }
        case .expanded:
            ExpandedMock(attributes: attributes, state: state).padding(.horizontal, 10)
        case .lockScreen:
            LockScreenMock(attributes: attributes, state: state).padding(.horizontal, 10)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }
}

// MARK: - Every state at a glance

private struct StateStrip: View {
    var body: some View {
        section("Every state") {
            VStack(spacing: 12) {
                ForEach(UploadPhase.allCases, id: \.self) { phase in
                    let state = UploadState(phase: phase, progress: 0.62, bytesSent: 0, bytesPerSecond: 0,
                                            secondsRemaining: nil, message: nil)
                    HStack {
                        Text(phase.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(phase.tint)
                            .frame(width: 80, alignment: .leading)
                        Spacer()
                        SplitCompactMock(attributes: sampleAttributes, state: state)
                            .scaleEffect(0.8)
                            .frame(width: 175, height: 30)
                        MinimalView(state: state)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(.black))
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(white: 0.16)))
        }
    }
}

// MARK: - Helpers

private let sampleAttributes = UploadActivityAttributes(fileName: "Vacation-4K.mov", fileSize: 486_000_000,
                                                        fileSymbol: "film", destination: "iCloud Drive")
private let sampleState = UploadState(phase: .uploading, progress: 0.42, bytesSent: 204_000_000,
                                      bytesPerSecond: 31_000_000, secondsRemaining: 9, message: nil)

private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
        content()
    }
}
