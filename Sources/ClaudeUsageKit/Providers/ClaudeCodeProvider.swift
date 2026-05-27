import Foundation

/// Reads Claude Code's local JSONL transcripts under `~/.claude/projects/`.
public struct ClaudeCodeProvider: UsageProvider {
    public let id = "claude-code"
    public let displayName = "Claude Code"

    private let aggregator: UsageAggregator

    public init(projectsDir: URL? = nil) {
        if let dir = projectsDir {
            self.aggregator = UsageAggregator(projectsDir: dir)
        } else {
            self.aggregator = UsageAggregator()
        }
    }

    public var isAvailable: Bool {
        FileManager.default.fileExists(atPath: aggregator.projectsDir.path)
    }

    public func loadAllEvents() async throws -> [UsageEvent] {
        try aggregator.loadAllEvents()
    }

    public func currentFrame(now: Date = Date()) async throws -> RateLimitFrame? {
        try aggregator.currentFrame(now: now)
    }
}
