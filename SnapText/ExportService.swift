//
//  ExportService.swift
//  SnapText
//
//  Created by Aditi More on 8/8/25.
//


import SwiftUI
import UniformTypeIdentifiers
import UIKit
import MobileCoreServices
import Foundation
import PDFKit

class ExportService {
    static func exportTextAsTXT(_ text: String) -> URL? {
        let fileName = "SnapText-\(UUID().uuidString.prefix(5)).txt"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    static func exportTextAsPDF(_ text: String) -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "SnapText",
            kCGPDFContextAuthor: "SnapText App"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let fileName = "SnapText-\(UUID().uuidString.prefix(5)).pdf"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try renderer.writePDF(to: fileURL) { context in
                context.beginPage()
                let textFont = UIFont.systemFont(ofSize: 14)
                let attributes: [NSAttributedString.Key: Any] = [.font: textFont]
                let attributedText = NSAttributedString(string: text, attributes: attributes)
                attributedText.draw(in: CGRect(x: 20, y: 20, width: pageRect.width - 40, height: pageRect.height - 40))
            }
            return fileURL
        } catch {
            print("Error creating PDF: \(error)")
            return nil
        }
    }

    static func exportTextAsXLS(_ text: String) -> URL? {
        let fileName = "SnapText-\(UUID().uuidString.prefix(5)).xls"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    // DOCX support can be added via third-party libraries like SwiftDocx or WordWriter
    static func exportTextAsDOCX(_ text: String) -> URL? {
        let fileName = "SnapText-\(UUID().uuidString.prefix(5)).docx"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? text.write(to: fileURL, atomically: true, encoding: .utf8) // temporary placeholder
        return fileURL
    }
}
