import Foundation

/// Parses Claude Code JSONL transcripts into `UsageEvent`s.
///
/// Each line in a transcript is a JSON object. We only care about assistant
/// messages that include a `usage` block. Lines are deduplicated by `requestId`
/// because Anthropic emits multiple message chunks per request (each with the
/// same `usage` snapshot — counting them all would multiply tokens).
public enum JSONLParser {

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    public static func parseFile(at url: URL) throws -> [UsageEvent] {
        guard let stream = InputStream(url: url) else {
            throw NSError(domain: "JSONLParser", code: 1)
        }
        stream.open()
        defer { stream.close() }

        var events: [UsageEvent] = []
        var seenRequestIds = Set<String>()

        let data = try Data(contentsOf: url)
        data.split(separator: 0x0A /* \n */).forEach { line in
            guard !line.isEmpty,
                  let event = parseLine(Data(line)),
                  !seenRequestIds.contains(event.requestId) else { return }
            seenRequestIds.insert(event.requestId)
            events.append(event)
        }
        return events
    }

    /// Parse a single line. Returns nil if it's not an assistant-with-usage entry.
    static func parseLine(_ data: Data) -> UsageEvent? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard (obj["type"] as? String) == "assistant" else { return nil }
        guard let message = obj["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any],
              let model = message["model"] as? String,
              let timestampStr = obj["timestamp"] as? String,
              let timestamp = iso.date(from: timestampStr),
              let requestId = obj["requestId"] as? String,
              let sessionId = obj["sessionId"] as? String else { return nil }

        let input = usage["input_tokens"] as? Int ?? 0
        let output = usage["output_tokens"] as? Int ?? 0
        let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0

        // cache_creation_input_tokens is the rolled-up total; the nested
        // cache_creation dict breaks it down by TTL. Prefer the breakdown
        // when present so we can price 5m and 1h separately.
        let cacheCreateTotal = usage["cache_creation_input_tokens"] as? Int ?? 0
        let nested = usage["cache_creation"] as? [String: Any]
        let cc5m = nested?["ephemeral_5m_input_tokens"] as? Int ?? 0
        let cc1h = nested?["ephemeral_1h_input_tokens"] as? Int ?? 0

        // If nested fields are missing assume it's all 5m (Anthropic's
        // pre-1h-cache default rate).
        let resolved5m: Int
        let resolved1h: Int
        if nested == nil {
            resolved5m = cacheCreateTotal
            resolved1h = 0
        } else {
            resolved5m = cc5m
            resolved1h = cc1h
        }

        return UsageEvent(
            timestamp: timestamp,
            requestId: requestId,
            sessionId: sessionId,
            model: model,
            inputTokens: input,
            outputTokens: output,
            cacheCreation5mTokens: resolved5m,
            cacheCreation1hTokens: resolved1h,
            cacheReadTokens: cacheRead
        )
    }
}
