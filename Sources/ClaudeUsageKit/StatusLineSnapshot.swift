import Foundation

/// The exact rate-limit numbers Claude Code feeds into a statusLine command's
/// stdin JSON (`rate_limits` object), persisted to disk by our statusLine
/// bridge script. This is the SAME data the `/usage` UI shows — no estimation.
///
/// Available for Pro/Max subscribers on Claude Code v2.1.80+ after the first
/// API response of a session. May be absent (older CC, free tier, or the
/// known Max-20x oauth gap) — callers should fall back to cost estimation.
public struct StatusLineSnapshot: Sendable, Codable, Equatable {
    public struct Bucket: Sendable, Codable, Equatable {
        /// 0–100.
        public let usedPercentage: Double
        /// When this window resets (Unix epoch seconds).
        public let resetsAt: TimeInterval

        public var resetsAtDate: Date { Date(timeIntervalSince1970: resetsAt) }
        public var timeRemaining: TimeInterval { max(0, resetsAtDate.timeIntervalSinceNow) }

        public init(usedPercentage: Double, resetsAt: TimeInterval) {
            self.usedPercentage = usedPercentage
            self.resetsAt = resetsAt
        }
    }

    public let fiveHour: Bucket?
    public let sevenDay: Bucket?
    /// When the bridge wrote this snapshot (Unix epoch seconds). Lets callers
    /// decide whether the data is fresh enough to trust.
    public let capturedAt: TimeInterval

    public var capturedAtDate: Date { Date(timeIntervalSince1970: capturedAt) }

    public init(fiveHour: Bucket?, sevenDay: Bucket?, capturedAt: TimeInterval) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.capturedAt = capturedAt
    }
}

public enum StatusLineSnapshotReader {
    /// Default snapshot path written by the bridge script.
    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/ratelimit-monitor/snapshot.json")
    }

    /// Read + decode the snapshot. Returns nil if the file is missing or
    /// malformed (caller falls back to estimation).
    public static func read(from url: URL = defaultURL) -> StatusLineSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(StatusLineSnapshot.self, from: data)
    }
}
