import XCTest
@testable import ClaudeUsageKit

final class ParserTests: XCTestCase {

    func testParseLineWithUsage() {
        let line = #"""
        {"type":"assistant","message":{"model":"claude-opus-4-7","usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":100,"cache_read_input_tokens":50}},"timestamp":"2026-05-25T04:13:53.233Z","requestId":"req_X","sessionId":"sess_Y"}
        """#
        let event = JSONLParser.parseLine(line.data(using: .utf8)!)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.inputTokens, 10)
        XCTAssertEqual(event?.outputTokens, 20)
        XCTAssertEqual(event?.cacheCreationTokens, 100)
        XCTAssertEqual(event?.cacheReadTokens, 50)
        XCTAssertEqual(event?.requestId, "req_X")
        XCTAssertEqual(event?.model, "claude-opus-4-7")
    }

    func testIgnoresNonAssistantLines() {
        let line = #"{"type":"user","content":"hi"}"#
        XCTAssertNil(JSONLParser.parseLine(line.data(using: .utf8)!))
    }

    func testIgnoresAssistantWithoutUsage() {
        let line = #"{"type":"assistant","message":{"model":"x"},"timestamp":"2026-05-25T04:13:53.233Z","requestId":"r","sessionId":"s"}"#
        XCTAssertNil(JSONLParser.parseLine(line.data(using: .utf8)!))
    }

    func testPricingOpus() {
        let event = UsageEvent(
            timestamp: Date(), requestId: "r", sessionId: "s",
            model: "claude-opus-4-7",
            inputTokens: 1_000_000, outputTokens: 0,
            cacheCreationTokens: 0, cacheReadTokens: 0
        )
        XCTAssertEqual(PricingTable.default.cost(for: event), 15.0, accuracy: 0.001)
    }
}
