import Foundation

/// Per-million-token prices in USD. Anthropic distinguishes two cache TTLs:
/// 5-minute ephemeral (1.25× input) and 1-hour ephemeral (2.00× input).
/// Claude Code uses the 1-hour TTL by default for its session context, so the
/// 1h rate dominates for CC users — counting all cache_creation at the 5m rate
/// under-estimates real cost by ~60% on that column.
public struct ModelPrice: Sendable {
    public let input: Double
    public let output: Double
    public let cacheWrite5m: Double
    public let cacheWrite1h: Double
    public let cacheRead: Double

    public init(input: Double, output: Double,
                cacheWrite5m: Double, cacheWrite1h: Double, cacheRead: Double) {
        self.input = input
        self.output = output
        self.cacheWrite5m = cacheWrite5m
        self.cacheWrite1h = cacheWrite1h
        self.cacheRead = cacheRead
    }

    /// Legacy initializer kept for source compatibility — derives 1h rate as
    /// input × 2.0, matching Anthropic's published multipliers.
    public init(input: Double, output: Double, cacheWrite: Double, cacheRead: Double) {
        self.init(input: input, output: output,
                  cacheWrite5m: cacheWrite,
                  cacheWrite1h: input * 2.0,
                  cacheRead: cacheRead)
    }
}

public struct PricingTable: Sendable {
    public let prices: [String: ModelPrice]
    public let fallback: ModelPrice

    public func cost(for event: UsageEvent) -> Double {
        let p = prices[event.model]
            ?? prices.first { event.model.contains($0.key) }?.value
            ?? fallback
        return (Double(event.inputTokens) * p.input
              + Double(event.outputTokens) * p.output
              + Double(event.cacheCreation5mTokens) * p.cacheWrite5m
              + Double(event.cacheCreation1hTokens) * p.cacheWrite1h
              + Double(event.cacheReadTokens) * p.cacheRead) / 1_000_000
    }

    /// Anthropic's published rates as of 2026-05. Verify against the price page
    /// before relying on absolute dollar figures for billing.
    public static let `default` = PricingTable(
        prices: [
            "claude-opus-4":   ModelPrice(input: 15,  output: 75, cacheWrite5m: 18.75, cacheWrite1h: 30.0, cacheRead: 1.5),
            "claude-sonnet-4": ModelPrice(input: 3,   output: 15, cacheWrite5m: 3.75,  cacheWrite1h: 6.0,  cacheRead: 0.3),
            "claude-haiku-4":  ModelPrice(input: 0.8, output: 4,  cacheWrite5m: 1.0,   cacheWrite1h: 1.6,  cacheRead: 0.08),
        ],
        fallback: ModelPrice(input: 3, output: 15, cacheWrite5m: 3.75, cacheWrite1h: 6.0, cacheRead: 0.3)
    )
}
