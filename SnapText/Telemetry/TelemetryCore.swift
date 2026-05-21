import Foundation
import Combine
import OSLog

enum TelemetryEventName: String, Codable, CaseIterable {
    case parseStarted = "parse_started"
    case parseSucceeded = "parse_succeeded"
    case parseFailed = "parse_failed"
    case parseCancelled = "parse_cancelled"
    case tableDetected = "table_detected"
    case tableDetectionFailed = "table_detection_failed"
    case fallbackToTextMode = "fallback_to_text_mode"
    case cameraOpened = "camera_opened"
    case imageSelected = "image_selected"
    case cropAdjusted = "crop_adjusted"
    case parseModeSwitched = "parse_mode_switched"
    case documentSaved = "document_saved"
    case documentDeleted = "document_deleted"
    case exportStarted = "export_started"
    case exportSucceeded = "export_succeeded"
    case exportFailed = "export_failed"
    case exportPDF = "export_pdf"
    case exportDOCX = "export_docx"
    case exportXLSX = "export_xlsx"
}

enum PrivacyClassification: String, Codable { case anonymousMetadataOnly, aggregateOnly, diagnostics }

struct TelemetryEvent: Codable, Identifiable {
    let id: UUID
    let name: TelemetryEventName
    let timestamp: Date
    let sessionHash: String
    let classification: PrivacyClassification
    let metadata: [String: String]

    init(name: TelemetryEventName, sessionHash: String, classification: PrivacyClassification = .anonymousMetadataOnly, metadata: [String: String] = [:]) {
        self.id = UUID(); self.name = name; self.timestamp = Date(); self.sessionHash = sessionHash; self.classification = classification; self.metadata = metadata
    }
}

actor TelemetrySessionManager {
    private let salt = "snaptext.telemetry.salt.v1"
    private(set) var sessionID = UUID().uuidString
    func rotate() { sessionID = UUID().uuidString }
    func sessionHash() -> String { String((sessionID + salt).hashValue.magnitude, radix: 16) }
}

actor TelemetryStorage {
    private let url: URL
    init(filename: String = "telemetry_queue.json") {
        url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
    }
    func load() -> [TelemetryEvent] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([TelemetryEvent].self, from: data)) ?? []
    }
    func save(_ events: [TelemetryEvent]) {
        if let data = try? JSONEncoder().encode(events) { try? data.write(to: url, options: .atomic) }
    }
    func exportURL() -> URL? { url }
    func clear() { try? FileManager.default.removeItem(at: url) }
}

actor TelemetryQueue {
    private(set) var events: [TelemetryEvent] = []
    private let maxSize = 2000
    private let storage: TelemetryStorage
    init(storage: TelemetryStorage) { self.storage = storage }
    func bootstrap() async { events = await storage.load(); trimIfNeeded() }
    func enqueue(_ event: TelemetryEvent) async {
        events.append(event); trimIfNeeded(); await storage.save(events)
    }
    func drain(batchSize: Int) async -> [TelemetryEvent] { Array(events.prefix(batchSize)) }
    func acknowledge(count: Int) async { events.removeFirst(min(count, events.count)); await storage.save(events) }
    func size() -> Int { events.count }
    func snapshot() -> [TelemetryEvent] { events }
    func clear() async { events.removeAll(); await storage.clear() }
    private func trimIfNeeded() { if events.count > maxSize { events.removeFirst(events.count - maxSize) } }
}

actor BatchUploader {
    private var attempt = 0
    func upload(_ events: [TelemetryEvent]) async throws {
        guard !events.isEmpty else { return }
        try await Task.sleep(nanoseconds: 80_000_000)
        if Int.random(in: 0..<10) < 2 { throw URLError(.timedOut) }
        attempt = 0
    }
    func nextBackoff() -> UInt64 { attempt += 1; return UInt64(min(pow(2.0, Double(attempt)), 60.0) * 1_000_000_000) }
}

struct KPIReport {
    let ocrSuccessRate: Double
    let averageOCRDuration: Double
    let exportSuccessRate: Double
    let averageExportDuration: Double
    let parseCancellationRate: Double
    let tableDetectionSuccessRate: Double
    let retryFrequency: Double
    let documentSaveRate: Double
}

enum KPIEngine {
    static func report(events: [TelemetryEvent]) -> KPIReport {
        func rate(_ num: Double, _ den: Double) -> Double { den == 0 ? 0 : num/den }
        let parseStart = events.filter{$0.name == .parseStarted}.count
        let parseSuccess = events.filter{$0.name == .parseSucceeded}.count
        let parseCancel = events.filter{$0.name == .parseCancelled}.count
        let tableSucc = events.filter{$0.name == .tableDetected}.count
        let tableFail = events.filter{$0.name == .tableDetectionFailed}.count
        let expSucc = events.filter{$0.name == .exportSucceeded}.count
        let expFail = events.filter{$0.name == .exportFailed}.count
        let saves = events.filter{$0.name == .documentSaved}.count
        let retries = events.compactMap{Int($0.metadata["retry_count"] ?? "")}.reduce(0,+)
        let ocrDur = events.compactMap{Double($0.metadata["ocr_duration_ms"] ?? "")}
        let expDur = events.compactMap{Double($0.metadata["export_duration_ms"] ?? "")}
        return KPIReport(ocrSuccessRate: rate(Double(parseSuccess), Double(parseStart)), averageOCRDuration: ocrDur.isEmpty ? 0 : ocrDur.reduce(0,+)/Double(ocrDur.count), exportSuccessRate: rate(Double(expSucc), Double(expSucc+expFail)), averageExportDuration: expDur.isEmpty ? 0 : expDur.reduce(0,+)/Double(expDur.count), parseCancellationRate: rate(Double(parseCancel), Double(parseStart)), tableDetectionSuccessRate: rate(Double(tableSucc), Double(tableSucc+tableFail)), retryFrequency: rate(Double(retries), Double(max(parseStart,1))), documentSaveRate: rate(Double(saves), Double(max(parseSuccess,1))))
    }
}

@MainActor
final class TelemetryManager: ObservableObject {
    static let shared = TelemetryManager()
    @Published var liveEvents: [TelemetryEvent] = []
    @Published var recentFailures: [String] = []
    @Published var telemetryEnabled = true
    @Published var isUploading = false

    private let logger = Logger(subsystem: "com.snaptext.app", category: "Telemetry")
    private let queue: TelemetryQueue
    private let uploader = BatchUploader()
    private let session = TelemetrySessionManager()
    private var timerTask: Task<Void, Never>?

    private init() {
        let storage = TelemetryStorage()
        self.queue = TelemetryQueue(storage: storage)
        Task { await queue.bootstrap(); await refreshLive(); startTimers() }
    }

    func track(_ name: TelemetryEventName, metadata: [String: String] = [:], classification: PrivacyClassification = .anonymousMetadataOnly) {
        guard telemetryEnabled else { return }
        Task {
            let redacted = metadata.filter { !$0.key.lowercased().contains("text") }
            var noisy = redacted
            if let val = Double(redacted["ocr_duration_ms"] ?? "") { noisy["ocr_duration_ms"] = String(Int(val + Double.random(in: -4...4))) }
            let event = TelemetryEvent(name: name, sessionHash: await session.sessionHash(), classification: classification, metadata: noisy)
            await queue.enqueue(event)
            logger.log("event=\(name.rawValue, privacy: .public)")
            await refreshLive()
            if await queue.size() >= 20 { await flush() }
        }
    }

    func flush() async {
        let batch = await queue.drain(batchSize: 20)
        guard !batch.isEmpty else { return }
        isUploading = true
        do {
            try await uploader.upload(batch)
            await queue.acknowledge(count: batch.count)
        } catch {
            recentFailures.insert(error.localizedDescription, at: 0)
            let wait = await uploader.nextBackoff()
            try? await Task.sleep(nanoseconds: wait)
        }
        isUploading = false
        await refreshLive()
    }

    func snapshotKPI() async -> KPIReport { KPIEngine.report(events: await queue.snapshot()) }
    func queueSize() async -> Int { await queue.size() }
    func clear() { Task { await queue.clear(); await refreshLive() } }
    func exportURL() -> URL? { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("telemetry_queue.json") }

    private func startTimers() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await flush()
            }
        }
    }

    private func refreshLive() async { let events = await queue.snapshot(); await MainActor.run { self.liveEvents = events.suffix(200).reversed() } }
}
