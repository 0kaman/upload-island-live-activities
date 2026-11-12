import SwiftUI

/// A stadium-shaped outline that mirrors the Dynamic Island's edge.
///
/// Progress is mapped onto the outline clockwise, starting at top-center:
///   - the trailing half (right of the camera) covers 0 – 50 %
///   - the leading half (left of the camera) covers 50 – 100 %
/// The real compact island renders leading and trailing as two separate regions,
/// so each one draws its own half and together they read as one continuous ring.
struct IslandBoundary: Shape {
    enum Segment {
        /// Whole pill, starting at top-center (used by the in-app mock).
        case full
        /// Right half: top-inner edge → around the right cap → bottom-inner edge.
        case trailingHalf
        /// Left half: bottom-inner edge → around the left cap → top-inner edge.
        case leadingHalf
    }

    var segment: Segment
    /// Insets the path so a stroke of this width isn't clipped by the frame.
    var inset: CGFloat = 0

    func path(in frame: CGRect) -> Path {
        let rect = frame.insetBy(dx: inset, dy: inset)
        let r = rect.height / 2
        var p = Path()

        switch segment {
        case .full:
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            p.addRelativeArc(center: CGPoint(x: rect.maxX - r, y: rect.midY), radius: r,
                             startAngle: .degrees(-90), delta: .degrees(180))
            p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
            p.addRelativeArc(center: CGPoint(x: rect.minX + r, y: rect.midY), radius: r,
                             startAngle: .degrees(90), delta: .degrees(180))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))

        case .trailingHalf:
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: max(rect.minX, rect.maxX - r), y: rect.minY))
            p.addRelativeArc(center: CGPoint(x: rect.maxX - r, y: rect.midY), radius: r,
                             startAngle: .degrees(-90), delta: .degrees(180))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))

        case .leadingHalf:
            p.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: min(rect.maxX, rect.minX + r), y: rect.maxY))
            p.addRelativeArc(center: CGPoint(x: rect.minX + r, y: rect.midY), radius: r,
                             startAngle: .degrees(90), delta: .degrees(180))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        return p
    }

    /// How much of a given segment is filled for an overall progress value.
    static func fill(for segment: Segment, progress: Double) -> Double {
        let p = min(max(progress, 0), 1)
        switch segment {
        case .full: return p
        case .trailingHalf: return min(p * 2, 1)
        case .leadingHalf: return max(p * 2 - 1, 0)
        }
    }
}

/// Track + progress stroke drawn along an `IslandBoundary` segment.
struct BoundaryProgressView: View {
    var segment: IslandBoundary.Segment
    var state: UploadState
    var lineWidth: CGFloat = 3

    var body: some View {
        let shape = IslandBoundary(segment: segment, inset: lineWidth / 2)
        let fill = state.phase == .completed ? 1 : IslandBoundary.fill(for: segment, progress: state.progress)
        let tint = state.phase.tint

        ZStack {
            if state.phase == .queued {
                shape.stroke(tint.opacity(0.55),
                             style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [2, 5]))
            } else {
                shape.stroke(tint.opacity(0.18), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
            shape
                .trim(from: 0, to: fill)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round,
                                                 dash: state.phase == .paused ? [6, 4] : []))
                .shadow(color: tint.opacity(state.phase == .uploading ? 0.9 : 0), radius: 3)
        }
    }
}

/// Circular ring for the minimal presentation – the island *is* a circle there,
/// so the ring sits right on its boundary.
struct RingProgressView: View {
    var state: UploadState
    var lineWidth: CGFloat = 3

    var body: some View {
        let tint = state.phase.tint
        let fill = state.phase == .completed ? 1 : min(max(state.progress, 0), 1)
        ZStack {
            Circle()
                .inset(by: lineWidth / 2)
                .stroke(tint.opacity(state.phase == .queued ? 0.55 : 0.18),
                        style: StrokeStyle(lineWidth: lineWidth,
                                           dash: state.phase == .queued ? [2, 4] : []))
            Circle()
                .inset(by: lineWidth / 2)
                .trim(from: 0, to: fill)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: state.phase.symbol)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(tint)
        }
    }
}
