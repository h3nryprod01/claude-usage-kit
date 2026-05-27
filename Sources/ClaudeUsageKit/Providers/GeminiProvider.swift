import Foundation

/// Gemini doesn't expose a usage endpoint. The only realtime signal is
/// `usageMetadata` in each Generate response. So this provider only works in
/// "local proxy mode" — the user routes their Gemini calls through our local
/// proxy (port 9090), which logs usage to ~/Library/Application Support/
/// RateLimitMonitor/gemini-usage.jsonl.
///
/// Until the proxy ships this is a stub that reports unavailable.
public struct GeminiProvider: UsageProvider {
    public let id = "gemini"
    public let displayName = "Gemini"

    private let logPath: URL

    public init(logPath: URL? = nil) {
        self.logPath = logPath ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RateLimitMonitor/gemini-usage.jsonl")
    }

    public var isAvailable: Bool {
        FileManager.default.fileExists(atPath: logPath.path)
    }

    public func loadAllEvents() async throws -> [UsageEvent] {
        guard isAvailable else { return [] }
        // Reuse JSONLParser-style approach; the proxy writes one usage event per line
        // in a compatible schema.
        return try JSONLParser.parseFile(at: logPath)
    }

    public func currentFrame(now: Date) async throws -> RateLimitFrame? {
        // Gemini uses daily quotas, not 5h frames.
        return nil
    }
}
