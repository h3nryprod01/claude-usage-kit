import Foundation

/// High-level API: scan all Claude Code transcripts and produce rate-limit info.
public struct UsageAggregator: Sendable {
    public let projectsDir: URL

    public init(projectsDir: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects", isDirectory: true)
    ) {
        self.projectsDir = projectsDir
    }

    /// Scan every *.jsonl under projectsDir and return events globally
    /// deduplicated by requestId, sorted by timestamp.
    public func loadAllEvents() throws -> [UsageEvent] {
        let fm = FileManager.default
        guard let it = fm.enumerator(at: projectsDir,
                                     includingPropertiesForKeys: [.isRegularFileKey],
                                     options: [.skipsHiddenFiles]) else { return [] }

        var seen = Set<String>()
        var all: [UsageEvent] = []
        for case let url as URL in it where url.pathExtension == "jsonl" {
            let events = (try? JSONLParser.parseFile(at: url)) ?? []
            for ev in events where !seen.contains(ev.requestId) {
                seen.insert(ev.requestId)
                all.append(ev)
            }
        }
        return all.sorted { $0.timestamp < $1.timestamp }
    }

    public func eventsInLast(_ interval: TimeInterval, now: Date = Date()) throws -> UsageWindow {
        let start = now.addingTimeInterval(-interval)
        let events = try loadAllEvents().filter { $0.timestamp >= start && $0.timestamp <= now }
        return UsageWindow(start: start, end: now, events: events)
    }

    /// Detect the active Anthropic 5-hour rate-limit frame using fixed 5h
    /// blocks (matches how Claude Code's /usage UI reports "resets in X").
    ///
    /// Algorithm — walk events oldest → newest. Each event either fits in the
    /// current block, or (if its timestamp is past `block_start + 5h`) starts
    /// a NEW block. The last block walked is the current one. If `now` is past
    /// that block's end, no frame is active.
    ///
    /// Why not a sliding 5h window: sliding counts every event in the last 5h
    /// regardless of where the block boundary is, so it overcounts dramatically
    /// when the user just started a fresh block but had heavy activity in the
    /// previous one.
    public func currentFrame(now: Date = Date()) throws -> RateLimitFrame? {
        let events = try loadAllEvents()
        guard let first = events.first else { return nil }

        let frameLength: TimeInterval = 18_000   // 5h
        var blockStart = first.timestamp
        for ev in events where ev.timestamp >= blockStart.addingTimeInterval(frameLength) {
            blockStart = ev.timestamp
        }
        let blockEnd = blockStart.addingTimeInterval(frameLength)
        guard now < blockEnd else { return nil }

        let inFrame = events.filter { $0.timestamp >= blockStart && $0.timestamp <= now }
        let window = UsageWindow(start: blockStart, end: blockEnd, events: inFrame)
        return RateLimitFrame(frameStart: blockStart, frameEnd: blockEnd, usage: window)
    }
}
