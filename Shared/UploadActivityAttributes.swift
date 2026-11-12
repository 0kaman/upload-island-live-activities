import ActivityKit
import Foundation

/// Static data for one upload. Set once when the Live Activity is requested.
struct UploadActivityAttributes: ActivityAttributes {
    typealias ContentState = UploadState

    var fileName: String
    var fileSize: Int64
    /// SF Symbol describing the file type.
    var fileSymbol: String
    var destination: String
}

/// Lifecycle of a simulated upload.
enum UploadPhase: String, Codable, Hashable, CaseIterable {
    case queued
    case uploading
    case paused
    case failed
    case retrying
    case completed
    case cancelled

    var title: String {
        switch self {
        case .queued: "Waiting"
        case .uploading: "Uploading"
        case .paused: "Paused"
        case .failed: "Failed"
        case .retrying: "Retrying"
        case .completed: "Uploaded"
        case .cancelled: "Cancelled"
        }
    }

    var isTerminal: Bool { self == .completed || self == .cancelled }
}

/// Dynamic data pushed to the Live Activity on every update.
struct UploadState: Codable, Hashable {
    var phase: UploadPhase
    /// 0...1
    var progress: Double
    var bytesSent: Int64
    var bytesPerSecond: Double
    var secondsRemaining: Int?
    var message: String?
}
