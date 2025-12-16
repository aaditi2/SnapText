import SwiftUI

@MainActor
final class ContentViewModel: ObservableObject {
    enum ParseMode { case text, table }

    @Published var selectedImage: UIImage?
    @Published var extractedText: String = ""
    @Published var savedDocs: [SavedDoc] = []
    @Published var parseMode: ParseMode = .text
    @Published var suggestedIsTable: Bool = false

    private var currentParseToken = UUID()

    var hasExtractedText: Bool {
        !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func handleNewImage(_ image: UIImage) {
        selectedImage = image
        extractedText = ""
        suggestedIsTable = false
        parseMode = .text

        let token = startNewParseRequest()

        Task(priority: .userInitiated) {
            await detectAndPopulate(for: image, token: token)
        }
    }

    func reparseCurrentImage() {
        guard let image = selectedImage else { return }
        let token = startNewParseRequest()

        Task(priority: .userInitiated) {
            switch parseMode {
            case .table:
                if let detected = await detectTable(in: image, mode: .fast),
                   isGoodTable(detected.rows) {
                    guard token == currentParseToken else { return }
                    extractedText = tsv(from: detected.rows)
                } else {
                    guard token == currentParseToken else { return }
                    extractedText = "No table detected. Try switching to Text."
                }
            case .text:
                await parseAsText(image, token: token)
            }
        }
    }

    func cancelExtraction() {
        extractedText = ""
        selectedImage = nil
        suggestedIsTable = false
        parseMode = .text
    }

    func saveCurrentExtraction() {
        guard hasExtractedText else { return }
        let fileType: DocFileType = (parseMode == .table) ? .spreadsheet : .text
        let doc = SavedDoc(id: UUID(), title: "Untitled", text: extractedText, fileType: fileType)
        savedDocs.append(doc)
        cancelExtraction()
    }

    private func detectAndPopulate(for image: UIImage, token: UUID) async {
        if let detected = await detectTable(in: image, mode: .fast),
           isGoodTable(detected.rows) {
            guard token == currentParseToken else { return }
            suggestedIsTable = true
            parseMode = .table
            extractedText = tsv(from: detected.rows)
        } else {
            await parseAsText(image, token: token)
        }
    }

    private func parseAsText(_ image: UIImage, token: UUID) async {
        do {
            let text = try await OCRService.recognizeText(in: image)
            guard token == currentParseToken else { return }
            extractedText = text
        } catch {
            guard token == currentParseToken else { return }
            extractedText = "Unable to extract text. Please try again."
        }
    }

    private func detectTable(in image: UIImage, mode: TableDetectMode) async -> DetectedTable? {
        await TableDetector.detect(from: image, mode: mode)
    }

    /// Quick sanity: need at least 2 rows * 2 cols and some non-empty cells.
    private func isGoodTable(_ rows: [[String]]) -> Bool {
        guard rows.count >= 2 else { return false }
        let maxCols = rows.map { $0.count }.max() ?? 0
        guard maxCols >= 2 else { return false }
        let nonEmpty = rows.flatMap { $0 }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return nonEmpty.count >= 4
    }

    private func tsv(from rows: [[String]]) -> String {
        rows.map { $0.joined(separator: "\t") }.joined(separator: "\n")
    }

    private func startNewParseRequest() -> UUID {
        let token = UUID()
        currentParseToken = token
        return token
    }
}
