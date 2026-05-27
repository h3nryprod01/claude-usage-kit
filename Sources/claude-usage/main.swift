import Foundation
import ClaudeUsageKit

let args = CommandLine.arguments.dropFirst()
let json = args.contains("--json")

let agg = UsageAggregator()

do {
    let frame = try agg.currentFrame()
    let last24h = try agg.eventsInLast(86_400)

    if json {
        let out: [String: Any] = [
            "frame_active": frame != nil,
            "frame_start": frame?.frameStart.ISO8601Format() as Any,
            "frame_end": frame?.frameEnd.ISO8601Format() as Any,
            "frame_input_tokens": frame?.usage.totalInputTokens ?? 0,
            "frame_output_tokens": frame?.usage.totalOutputTokens ?? 0,
            "frame_cache_read": frame?.usage.totalCacheRead ?? 0,
            "frame_cache_creation": frame?.usage.totalCacheCreation ?? 0,
            "frame_messages": frame?.usage.messageCount ?? 0,
            "frame_progress": frame?.progress ?? 0,
            "frame_seconds_remaining": Int(frame?.timeRemaining ?? 0),
            "frame_cost_usd": frame?.usage.estimatedCostUSD() ?? 0,
            "last24h_messages": last24h.messageCount,
            "last24h_cost_usd": last24h.estimatedCostUSD(),
        ]
        let data = try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted])
        print(String(data: data, encoding: .utf8)!)
    } else {
        print("Claude usage — 5h rolling frame")
        print(String(repeating: "─", count: 40))
        if let f = frame {
            let mins = Int(f.timeRemaining / 60)
            print("Frame:           \(f.frameStart.formatted(date: .omitted, time: .standard)) → \(f.frameEnd.formatted(date: .omitted, time: .standard))")
            print("Time remaining:  \(mins / 60)h \(mins % 60)m  (\(Int(f.progress * 100))% elapsed)")
            print("Messages:        \(f.usage.messageCount)  (\(f.usage.uniqueRequests) unique requests)")
            print("Input tokens:    \(f.usage.totalInputTokens.formatted())")
            print("Output tokens:   \(f.usage.totalOutputTokens.formatted())")
            print("Cache read:      \(f.usage.totalCacheRead.formatted())")
            print("Cache creation:  \(f.usage.totalCacheCreation.formatted())")
            print(String(format: "Estimated cost:  $%.4f", f.usage.estimatedCostUSD()))
        } else {
            print("No active 5h frame — last activity > 5h ago. Sending a 'hello' will start a new frame.")
        }
        print("")
        print("Last 24h: \(last24h.messageCount) messages, $\(String(format: "%.2f", last24h.estimatedCostUSD()))")
    }
} catch {
    FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
    exit(1)
}
