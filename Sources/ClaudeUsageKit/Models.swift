import Foundation

/// A single assistant message with usage data, parsed from a JSONL transcript.
public struct UsageEvent: Sendable, Hashable {
    public let timestamp: Date
    public let requestId: String
    public let sessionId: String
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    /// 5-minute ephemeral cache writes (Anthropic charges 1.25× input).
    public let cacheCreation5mTokens: Int
    /// 1-hour ephemeral cache writes (Anthropic charges 2.00× input). Claude Code
    /// uses the 1-hour TTL by default for its session context — this is usually
    /// the dominant cache_creation column for CC users.
    public let cacheCreation1hTokens: Int
    public let cacheReadTokens: Int

    /// Backwards-compatible total of both TTLs.
    public var cacheCreationTokens: Int { cacheCreation5mTokens + cacheCreation1hTokens }

    public var totalInputEquivalent: Int {
        inputTokens + cacheCreationTokens + cacheReadTokens
    }

    public init(
        timestamp: Date, requestId: String, sessionId: String, model: String,
        inputTokens: Int, outputTokens: Int,
        cacheCreation5mTokens: Int = 0, cacheCreation1hTokens: Int = 0,
        cacheReadTokens: Int
    ) {
        self.timestamp = timestamp
        self.requestId = requestId
        self.sessionId = sessionId
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreation5mTokens = cacheCreation5mTokens
        self.cacheCreation1hTokens = cacheCreation1hTokens
        self.cacheReadTokens = cacheReadTokens
    }

    /// Backwards-compatible initializer for callers that still pass a single
    /// `cacheCreationTokens`. Assumes the 5-minute TTL (Anthropic's original
    /// default before they introduced 1h ephemeral caches).
    public init(
        timestamp: Date, requestId: String, sessionId: String, model: String,
        inputTokens: Int, outputTokens: Int,
        cacheCreationTokens: Int, cacheReadTokens: Int
    ) {
        self.init(
            timestamp: timestamp, requestId: requestId, sessionId: sessionId,
            model: model, inputTokens: inputTokens, outputTokens: outputTokens,
            cacheCreation5mTokens: cacheCreationTokens, cacheCreation1hTokens: 0,
            cacheReadTokens: cacheReadTokens
        )
    }
}

/// Aggregated usage stats over a time window.
public struct UsageWindow: Sendable {
    public let start: Date
    public let end: Date
    public let events: [UsageEvent]

    public init(start: Date, end: Date, events: [UsageEvent]) {
        self.start = start
        self.end = end
        self.events = events
    }

    public var totalInputTokens: Int { events.reduce(0) { $0 + $1.inputTokens } }
    public var totalOutputTokens: Int { events.reduce(0) { $0 + $1.outputTokens } }
    public var totalCacheCreation: Int { events.reduce(0) { $0 + $1.cacheCreationTokens } }
    public var totalCacheCreation5m: Int { events.reduce(0) { $0 + $1.cacheCreation5mTokens } }
    public var totalCacheCreation1h: Int { events.reduce(0) { $0 + $1.cacheCreation1hTokens } }
    public var totalCacheRead: Int { events.reduce(0) { $0 + $1.cacheReadTokens } }
    public var messageCount: Int { events.count }
    public var uniqueRequests: Int { Set(events.map { $0.requestId }).count }

    public var firstEventAt: Date? { events.map(\.timestamp).min() }
    public var lastEventAt: Date? { events.map(\.timestamp).max() }

    /// Estimated cost in USD based on a pricing table.
    public func estimatedCostUSD(pricing: PricingTable = .default) -> Double {
        events.reduce(0) { $0 + pricing.cost(for: $1) }
    }
}

/// Anthropic 5-hour rolling rate-limit window.
/// The window starts at the time of the first message sent after a >=5h gap.
public struct RateLimitFrame: Sendable {
    public let frameStart: Date
    public let frameEnd: Date     // frameStart + 5h
    public let usage: UsageWindow

    public init(frameStart: Date, frameEnd: Date, usage: UsageWindow) {
        self.frameStart = frameStart
        self.frameEnd = frameEnd
        self.usage = usage
    }

    public var timeRemaining: TimeInterval { max(0, frameEnd.timeIntervalSinceNow) }
    public var elapsedSinceStart: TimeInterval { Date().timeIntervalSince(frameStart) }
    public var progress: Double { min(1.0, elapsedSinceStart / 18_000) } // 5h = 18000s

    public var isActive: Bool { Date() < frameEnd }
}
