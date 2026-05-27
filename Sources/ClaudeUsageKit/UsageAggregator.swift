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

    /// Detect the active Anthropic 5-hour rate-limit frame.
    ///
    /// Heuristic: the frame starts at the first message in the most recent
    /// burst, where a "burst" is a run of messages separated by < 5h gaps.
    /// If the most recent event is older than 5h ago, no frame is active.
    public func currentFrame(now: Date = Date()) throws -> RateLimitFrame? {
        let events = try loadAllEvents()
        guard let last = events.last, now.timeIntervalSince(last.timestamp) < 18_000 else {
            return nil
        }

        var frameStart = last.timestamp
        var prev = last.timestamp
        for ev in events.reversed() {
            if prev.timeIntervalSince(ev.timestamp) > 18_000 { break }
            frameStart = ev.timestamp
            prev = ev.timestamp
        }
        let frameEnd = frameStart.addingTimeInterval(18_000)
        let window = UsageWindow(start: frameStart, end: frameEnd,
                                 events: events.filter { $0.timestamp >= frameStart && $0.timestamp <= frameEnd })
        return RateLimitFrame(frameStart: frameStart, frameEnd: frameEnd, usage: window)
    }
}
