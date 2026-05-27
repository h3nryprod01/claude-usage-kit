import Foundation

/// Queries OpenAI's `/v1/organization/usage` endpoint.
///
/// CAVEAT: OpenAI usage has up to 24h delay and is org-scoped, not
/// user/key-scoped. For realtime tracking we need a local proxy (see
/// docs/data-sources.md, "Local proxy option"). This implementation is the
/// "good enough for daily totals" baseline.
///
/// Requires an admin API key stored under Keychain service "RateLimitMonitor",
/// account "openai".
public struct OpenAIProvider: UsageProvider {
    public let id = "openai"
    public let displayName = "OpenAI"

    private let session: URLSession
    private let keychainAccount: String

    public init(session: URLSession = .shared, keychainAccount: String = "openai") {
        self.session = session
        self.keychainAccount = keychainAccount
    }

    public var isAvailable: Bool {
        Keychain.fetch(service: "RateLimitMonitor", account: keychainAccount) != nil
    }

    public func loadAllEvents() async throws -> [UsageEvent] {
        guard let key = Keychain.fetch(service: "RateLimitMonitor", account: keychainAccount) else {
            return []
        }
        // Last 24h as a starting point; pagination & wider windows come later.
        let endTime = Int(Date().timeIntervalSince1970)
        let startTime = endTime - 86_400
        var url = URL(string: "https://api.openai.com/v1/organization/usage/completions")!
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "start_time", value: String(startTime)),
            URLQueryItem(name: "end_time", value: String(endTime)),
            URLQueryItem(name: "bucket_width", value: "1h"),
        ]
        url = comps.url!

        var req = URLRequest(url: url)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await session.data(for: req)
        return parseUsageResponse(data)
    }

    /// OpenAI returns `{ data: [{ start_time, results: [{ input_tokens, output_tokens, model }] }] }`.
    /// We synthesize one UsageEvent per bucket-model pair.
    func parseUsageResponse(_ data: Data) -> [UsageEvent] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let buckets = obj["data"] as? [[String: Any]] else { return [] }

        var events: [UsageEvent] = []
        for bucket in buckets {
            guard let startTime = bucket["start_time"] as? TimeInterval,
                  let results = bucket["results"] as? [[String: Any]] else { continue }
            let ts = Date(timeIntervalSince1970: startTime)
            for r in results {
                let model = r["model"] as? String ?? "openai-unknown"
                let input = r["input_tokens"] as? Int ?? 0
                let output = r["output_tokens"] as? Int ?? 0
                events.append(UsageEvent(
                    timestamp: ts,
                    requestId: "openai-\(Int(startTime))-\(model)",
                    sessionId: "openai",
                    model: model,
                    inputTokens: input,
                    outputTokens: output,
                    cacheCreationTokens: 0,
                    cacheReadTokens: r["input_cached_tokens"] as? Int ?? 0
                ))
            }
        }
        return events
    }

    public func currentFrame(now: Date) async throws -> RateLimitFrame? {
        // OpenAI has no 5h-style frame. Returning nil signals "use daily/RPM view instead".
        return nil
    }
}
