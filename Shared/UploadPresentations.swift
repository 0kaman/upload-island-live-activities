import SwiftUI

// MARK: - Phase styling

extension UploadPhase {
    var tint: Color {
        switch self {
        case .queued: Color(white: 0.7)
        case .uploading: Color(red: 0.25, green: 0.78, blue: 1.0)
        case .paused: Color(red: 1.0, green: 0.72, blue: 0.2)
        case .failed: Color(red: 1.0, green: 0.33, blue: 0.33)
        case .retrying: Color(red: 0.75, green: 0.55, blue: 1.0)
        case .completed: Color(red: 0.3, green: 0.9, blue: 0.5)
        case .cancelled: Color(white: 0.55)
        }
    }

    var symbol: String {
        switch self {
        case .queued: "clock"
        case .uploading: "arrow.up"
        case .paused: "pause.fill"
        case .failed: "exclamationmark"
        case .retrying: "arrow.clockwise"
        case .completed: "checkmark"
        case .cancelled: "xmark"
        }
    }
}

// MARK: - Formatting

enum UploadFormat {
    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }

    static func percent(_ progress: Double) -> String {
        "\(Int((min(max(progress, 0), 1) * 100).rounded(.down)))%"
    }

    static func remaining(_ seconds: Int) -> String {
        seconds >= 60 ? "\(seconds / 60)m \(seconds % 60)s left" : "\(seconds)s left"
    }

    static func detail(_ s: UploadState, _ a: UploadActivityAttributes) -> String {
        switch s.phase {
        case .queued: s.message ?? "Queued – starts shortly"
        case .uploading:
            [bytes(Int64(s.bytesPerSecond)) + "/s", s.secondsRemaining.map(remaining)]
                .compactMap { $0 }.joined(separator: " · ")
        case .paused: "Paused at \(percent(s.progress))"
        case .failed: s.message ?? "Connection lost"
        case .retrying: s.message ?? "Reconnecting…"
        case .completed: "Saved to \(a.destination)"
        case .cancelled: "Upload cancelled"
        }
    }
}

// MARK: - Compact (Dynamic Island, single activity)

struct CompactLeadingView: View {
    var attributes: UploadActivityAttributes
    var state: UploadState

    var body: some View {
        ZStack {
            BoundaryProgressView(segment: .leadingHalf, state: state)
            Image(systemName: attributes.fileSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.leading, 6)
        }
        .frame(width: 46)
    }
}

struct CompactTrailingView: View {
    var state: UploadState

    var body: some View {
        ZStack {
            BoundaryProgressView(segment: .trailingHalf, state: state)
            Group {
                if state.phase == .uploading {
                    Text(UploadFormat.percent(state.progress))
                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                } else {
                    Image(systemName: state.phase.symbol)
                        .font(.system(size: 12, weight: .heavy))
                }
            }
            .foregroundStyle(state.phase.tint)
            .padding(.trailing, 6)
        }
        .frame(width: 46)
    }
}

// MARK: - Minimal (Dynamic Island, multiple activities)

struct MinimalView: View {
    var state: UploadState

    var body: some View {
        RingProgressView(state: state, lineWidth: 2.5)
    }
}

// MARK: - Expanded regions

struct ExpandedLeadingView: View {
    var attributes: UploadActivityAttributes
    var state: UploadState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(state.phase.tint.opacity(0.18))
            Image(systemName: attributes.fileSymbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(state.phase.tint)
        }
        .frame(width: 44, height: 44)
        .padding(.leading, 4)
    }
}

struct ExpandedTrailingView: View {
    var state: UploadState

    var body: some View {
        ZStack {
            RingProgressView(state: state, lineWidth: 4)
                .frame(width: 44, height: 44)
            if state.phase == .uploading {
                // Cover the ring's center icon with the number.
                Circle().fill(.black).frame(width: 34, height: 34)
                Text(UploadFormat.percent(state.progress))
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        }
        .padding(.trailing, 4)
    }
}

struct ExpandedCenterView: View {
    var attributes: UploadActivityAttributes
    var state: UploadState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(attributes.fileName)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(.white)
            Text("\(state.phase.title) · \(attributes.destination)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(state.phase.tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ExpandedBottomView: View {
    var attributes: UploadActivityAttributes
    var state: UploadState

    var body: some View {
        VStack(spacing: 6) {
            LinearProgressBar(state: state, height: 6)
            HStack {
                Text("\(UploadFormat.bytes(state.bytesSent)) of \(UploadFormat.bytes(attributes.fileSize))")
                Spacer()
                Text(UploadFormat.detail(state, attributes))
            }
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.65))
            .lineLimit(1)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}

struct LinearProgressBar: View {
    var state: UploadState
    var height: CGFloat

    var body: some View {
        let fill = state.phase == .completed ? 1 : min(max(state.progress, 0), 1)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(state.phase.tint.opacity(0.2))
                Capsule()
                    .fill(state.phase.tint)
                    .frame(width: max(height, geo.size.width * fill))
                    .opacity(state.phase == .queued ? 0 : 1)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Lock Screen / banner

struct LockScreenView: View {
    var attributes: UploadActivityAttributes
    var state: UploadState

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ExpandedLeadingView(attributes: attributes, state: state)
                    .padding(.leading, -4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attributes.fileName)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    Text(UploadFormat.detail(state, attributes))
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Label(state.phase == .uploading ? UploadFormat.percent(state.progress) : state.phase.title,
                      systemImage: state.phase.symbol)
                    .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(state.phase.tint)
            }
            LinearProgressBar(state: state, height: 8)
            HStack {
                Text("\(UploadFormat.bytes(state.bytesSent)) of \(UploadFormat.bytes(attributes.fileSize))")
                Spacer()
                Text("→ \(attributes.destination)")
            }
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.white.opacity(0.5))
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}
