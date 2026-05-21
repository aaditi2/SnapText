import XCTest
@testable import SnapText

final class TelemetryTests: XCTestCase {
    func testKPIReportRates() {
        let e1 = TelemetryEvent(name: .parseStarted, sessionHash: "a")
        let e2 = TelemetryEvent(name: .parseSucceeded, sessionHash: "a", metadata: ["ocr_duration_ms": "100"])
        let e3 = TelemetryEvent(name: .exportSucceeded, sessionHash: "a", metadata: ["export_duration_ms": "200"])
        let e4 = TelemetryEvent(name: .exportFailed, sessionHash: "a")
        let report = KPIEngine.report(events: [e1,e2,e3,e4])
        XCTAssertEqual(report.ocrSuccessRate, 1.0)
        XCTAssertEqual(report.exportSuccessRate, 0.5)
        XCTAssertEqual(report.averageOCRDuration, 100)
    }

    func testQueuePersistenceAndClear() async {
        let storage = TelemetryStorage(filename: "telemetry_test.json")
        let queue = TelemetryQueue(storage: storage)
        await queue.enqueue(TelemetryEvent(name: .parseStarted, sessionHash: "1"))
        XCTAssertEqual(await queue.size(), 1)
        await queue.clear()
        XCTAssertEqual(await queue.size(), 0)
    }
}
