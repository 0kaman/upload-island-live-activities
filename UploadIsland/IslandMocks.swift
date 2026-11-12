import SwiftUI

/// In-app replicas of each Live Activity presentation, built from the same shared
/// views the widget uses. Unlike the real island, the app can draw the outline as
/// one continuous ring across the camera area.

/// Concept: a single continuous ring around the whole compact pill.
struct ContinuousCompactMock: View {
    var attributes: UploadActivityAttributes
    var state: UploadState

    var body: some View {
        ZStack {
            Capsule().fill(.black)
            BoundaryProgressView(segment: .full, state: state, lineWidth: 3)
            HStack {
                Image(systemName: attributes.fileSymbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                CompactTrailingLabel(state: state)
            }
            .padding(.horizontal, 16)
        }
        .frame(width: 236, height: 37)
        .animation(.easeOut(duration: 0.25), value: state)
    }
}

/// What the device renders: leading + trailing halves either side of the sensor.
struct SplitCompactMock: View {
    var attributes: UploadActivityAttributes
    var state: UploadState

    var body: some View {
        HStack(spacing: 0) {
            CompactLeadingView(attributes: attributes, state: state)
            Color.black.frame(width: 126)
            CompactTrailingView(state: state)
        }
        .frame(height: 37)
        .background(Capsule().fill(.black))
        .animation(.easeOut(duration: 0.25), value: state)
    }
}

private struct CompactTrailingLabel: View {
    var state: UploadState

    var body: some View {
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
    }
}

struct MinimalMock: View {
    var state: UploadState

    var body: some View {
        HStack(spacing: 6) {
            Capsule().fill(.black).frame(width: 150, height: 37)
            MinimalView(state: state)
                .frame(width: 37, height: 37)
                .background(Circle().fill(.black))
        }
        .animation(.easeOut(duration: 0.25), value: state)
    }
}

struct ExpandedMock: View {
    var attributes: UploadActivityAttributes
    var state: UploadState

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ExpandedLeadingView(attributes: attributes, state: state)
                ExpandedCenterView(attributes: attributes, state: state)
                ExpandedTrailingView(state: state)
            }
            ExpandedBottomView(attributes: attributes, state: state)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 44, style: .continuous).fill(.black))
        .animation(.easeOut(duration: 0.25), value: state)
    }
}

struct LockScreenMock: View {
    var attributes: UploadActivityAttributes
    var state: UploadState

    var body: some View {
        LockScreenView(attributes: attributes, state: state)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.85)))
            .animation(.easeOut(duration: 0.25), value: state)
    }
}
