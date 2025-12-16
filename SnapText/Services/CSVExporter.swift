import Foundation
import UIKit
import SwiftUI   // <- needed for UIViewControllerRepresentable & Context

enum TableExport {
    static func makeCSV(from rows: [[String]]) -> String {
        rows.map { row in
            row.map { escapeCSV($0) }.joined(separator: ",")
        }
        .joined(separator: "\n")
    }

    private static func escapeCSV(_ field: String) -> String {
        var f = field
        if f.contains("\"") { f = f.replacingOccurrences(of: "\"", with: "\"\"") }
        if f.contains(",") || f.contains("\n") || f.contains("\"") {
            return "\"\(f)\""
        }
        return f
    }

    static func writeTempCSV(_ csv: String, suggestedName: String = "table.csv") -> URL? {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(suggestedName)
        do {
            try csv.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            print("CSV write error:", error)
            return nil
        }
    }
}

/// Use this name to avoid clashing with any existing ShareSheet in your project.
struct ShareCSVSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
