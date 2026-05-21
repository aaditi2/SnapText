import Foundation
import Vision
import UIKit

enum OCRServiceError: Error {
    case invalidImage
}

struct OCRService {
    private static let telemetry = TelemetryManager.shared

    static func recognizeText(in image: UIImage, retryCount: Int = 0) async throws -> String {
        let start = Date()
        telemetry.track(.parseStarted, metadata: ["retry_count": "\(retryCount)"])
        guard let cgImage = image.cgImage else {
            telemetry.track(.parseFailed, metadata: ["error": "invalid_image"])
            throw OCRServiceError.invalidImage
        }

        do {
            let result = try await Task.detached(priority: .userInitiated) { () -> String in
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                if #available(iOS 16.0, *) { request.revision = VNRecognizeTextRequestRevision3 }
                try handler.perform([request])
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            }.value
            let duration = Int(Date().timeIntervalSince(start) * 1000)
            telemetry.track(.parseSucceeded, metadata: ["ocr_duration_ms": "\(duration)", "retry_count": "\(retryCount)"])
            return result
        } catch {
            telemetry.track(.parseFailed, metadata: ["error": "vision_failure", "retry_count": "\(retryCount)"])
            throw error
        }
    }
}
