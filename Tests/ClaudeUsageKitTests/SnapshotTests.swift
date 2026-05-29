import XCTest
@testable import ClaudeUsageKit

final class SnapshotTests: XCTestCase {
    func testDecodeFullSnapshot() throws {
        let json = #"""
        {"fiveHour":{"usedPercentage":70,"resetsAt":1742651200},
         "sevenDay":{"usedPercentage":25,"resetsAt":1743120000},
         "capturedAt":1742648000}
        """#
        let snap = try JSONDecoder().decode(StatusLineSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(snap.fiveHour?.usedPercentage, 70)
        XCTAssertEqual(snap.fiveHour?.resetsAt, 1742651200)
        XCTAssertEqual(snap.sevenDay?.usedPercentage, 25)
    }

    func testReadMissingFileReturnsNil() {
        let url = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).json")
        XCTAssertNil(StatusLineSnapshotReader.read(from: url))
    }

    func testRoundTripThroughDisk() throws {
        let url = URL(fileURLWithPath: "/tmp/rlm-snap-\(UUID().uuidString).json")
        let snap = StatusLineSnapshot(
            fiveHour: .init(usedPercentage: 42, resetsAt: 2_000_000_000),
            sevenDay: nil, capturedAt: 1_999_999_000)
        try JSONEncoder().encode(snap).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let read = StatusLineSnapshotReader.read(from: url)
        XCTAssertEqual(read?.fiveHour?.usedPercentage, 42)
        XCTAssertNil(read?.sevenDay)
        XCTAssertGreaterThan(read?.fiveHour?.timeRemaining ?? 0, 0)
    }
}
