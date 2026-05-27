import Foundation

/// A pluggable source of `UsageEvent`s for a given LLM provider.
///
/// Adapters live in `Providers/`. To add a new provider, conform a new type and
/// register it in `ProviderRegistry`.
public protocol UsageProvider: Sendable {
    /// Stable identifier, e.g. "claude-code", "openai", "gemini".
    var id: String { get }

    /// Display name, e.g. "Claude Code", "OpenAI".
    var displayName: String { get }

    /// Whether this provider is configured and ready to query (e.g. logs exist,
    /// API key in Keychain, etc.). Used to decide tab visibility in the app.
    var isAvailable: Bool { get }

    /// Load every event this provider has ever recorded, sorted ascending by
    /// timestamp, deduplicated by upstream id.
    func loadAllEvents() async throws -> [UsageEvent]

    /// Provider-specific rate-limit frame, if applicable.
    /// Claude has a 5h rolling frame; OpenAI has per-minute/day limits;
    /// Gemini has daily quotas. Returning `nil` means "no frame concept".
    func currentFrame(now: Date) async throws -> RateLimitFrame?
}

public extension UsageProvider {
    func eventsInLast(_ interval: TimeInterval, now: Date = Date()) async throws -> UsageWindow {
        let start = now.addingTimeInterval(-interval)
        let events = try await loadAllEvents().filter { $0.timestamp >= start && $0.timestamp <= now }
        return UsageWindow(start: start, end: now, events: events)
    }
}

/// Global registry. Apps construct this once and pass it to the UI.
public actor ProviderRegistry {
    public private(set) var providers: [any UsageProvider]

    public init(providers: [any UsageProvider]) {
        self.providers = providers
    }

    public func add(_ provider: any UsageProvider) {
        providers.append(provider)
    }

    public func available() -> [any UsageProvider] {
        providers.filter(\.isAvailable)
    }

    /// Convenience: registry with every built-in provider.
    public static func defaultRegistry() -> ProviderRegistry {
        ProviderRegistry(providers: [
            ClaudeCodeProvider(),
            OpenAIProvider(),
            GeminiProvider(),
        ])
    }
}
