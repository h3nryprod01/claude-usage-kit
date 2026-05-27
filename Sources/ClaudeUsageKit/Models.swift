import Foundation

/// A single assistant message with usage data, parsed from a JSONL transcript.
public struct UsageEvent: Sendable, Hashable {
    public let timestamp: Date
    public let requestId: String
    public let sessionId: String
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int

    public var totalInputEquivalent: Int {
        inputTokens + cacheCreationTokens + cacheReadTokens
    }
}

/// Aggregated usage stats over a time window.
public struct UsageWindow: Sendable {
    public let start: Date
    public let end: Date
    public let events: [UsageEvent]

    public var totalInputTokens: Int { events.reduce(0) { $0 + $1.inputTokens } }
    public var totalOutputTokens: Int { events.reduce(0) { $0 + $1.outputTokens } }
    public var totalCacheCreation: Int { events.reduce(0) { $0 + $1.cacheCreationTokens } }
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

    public var timeRemaining: TimeInterval { max(0, frameEnd.timeIntervalSinceNow) }
    public var elapsedSinceStart: TimeInterval { Date().timeIntervalSince(frameStart) }
    public var progress: Double { min(1.0, elapsedSinceStart / 18_000) } // 5h = 18000s

    public var isActive: Bool { Date() < frameEnd }
}
