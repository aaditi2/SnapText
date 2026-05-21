import SwiftUI
import UIKit
import Foundation
import PDFKit

class ExportService {
    private static let telemetry = TelemetryManager.shared

    static func exportTextAsPDF(_ text: String) -> URL? { export(type: .exportPDF) { _ in
        let pdfMetaData = [kCGPDFContextCreator: "SnapText", kCGPDFContextAuthor: "SnapText App"]
        let format = UIGraphicsPDFRendererFormat(); format.documentInfo = pdfMetaData as [String: Any]
        let pageRect = CGRect(x: 0, y: 0, width: 8.5 * 72.0, height: 11 * 72.0)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SnapText-\(UUID().uuidString.prefix(5)).pdf")
        try renderer.writePDF(to: url) { context in
            context.beginPage(); NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 14)]).draw(in: CGRect(x: 20, y: 20, width: pageRect.width - 40, height: pageRect.height - 40))
        }
        return url
    } }
    static func exportTextAsXLS(_ text: String) -> URL? { export(type: .exportXLSX) { name in let url = FileManager.default.temporaryDirectory.appendingPathComponent(name + ".xls"); try text.write(to: url, atomically: true, encoding: .utf8); return url } }
    static func exportTextAsDOCX(_ text: String) -> URL? { export(type: .exportDOCX) { name in let url = FileManager.default.temporaryDirectory.appendingPathComponent(name + ".docx"); try text.write(to: url, atomically: true, encoding: .utf8); return url } }

    private static func export(type: TelemetryEventName, block: (String) throws -> URL) -> URL? {
        telemetry.track(.exportStarted); telemetry.track(type)
        let start = Date()
        do {
            let url = try block("SnapText-\(UUID().uuidString.prefix(5))")
            telemetry.track(.exportSucceeded, metadata: ["export_duration_ms": "\(Int(Date().timeIntervalSince(start)*1000))"])
            return url
        } catch {
            telemetry.track(.exportFailed, metadata: ["error": error.localizedDescription])
            return nil
        }
    }
}
