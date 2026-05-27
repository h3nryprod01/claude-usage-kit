import Foundation

/// Per-million-token prices in USD. Update as Anthropic publishes new tiers.
public struct ModelPrice: Sendable {
    public let input: Double
    public let output: Double
    public let cacheWrite: Double
    public let cacheRead: Double
}

public struct PricingTable: Sendable {
    public let prices: [String: ModelPrice]
    public let fallback: ModelPrice

    public func cost(for event: UsageEvent) -> Double {
        let p = prices[event.model] ?? prices.first { event.model.contains($0.key) }?.value ?? fallback
        return (Double(event.inputTokens) * p.input
              + Double(event.outputTokens) * p.output
              + Double(event.cacheCreationTokens) * p.cacheWrite
              + Double(event.cacheReadTokens) * p.cacheRead) / 1_000_000
    }

    /// Indicative pricing — verify against current Anthropic price list before shipping.
    public static let `default` = PricingTable(
        prices: [
            "claude-opus-4": ModelPrice(input: 15, output: 75, cacheWrite: 18.75, cacheRead: 1.5),
            "claude-sonnet-4": ModelPrice(input: 3, output: 15, cacheWrite: 3.75, cacheRead: 0.3),
            "claude-haiku-4": ModelPrice(input: 0.8, output: 4, cacheWrite: 1.0, cacheRead: 0.08),
        ],
        fallback: ModelPrice(input: 3, output: 15, cacheWrite: 3.75, cacheRead: 0.3)
    )
}
