import SwiftUI
import Vision
import CoreGraphics

// Wrapper for Identifiable UIImage (unchanged)
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ContentView: View {

    // MARK: - UI State
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    @State private var showDocumentPicker = false

    @State private var selectedImage: UIImage?
    @State private var extractedText: String = ""
    @State private var savedDocs: [SavedDoc] = []

    // MARK: - Parsing mode UI
    enum ParseMode { case text, table }
    @State private var parseMode: ParseMode = .text
    @State private var suggestedIsTable: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // Header
                        VStack(spacing: 4) {
                            Image(systemName: "doc.text.viewfinder")
                                .resizable()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.accentColor)
                                .padding(.bottom, 4)

                            Text("SnapText")
                                .font(.system(size: 26, weight: .semibold))

                            Text("Capture. Extract. Edit.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)

                        // Upload Menu
                        Menu {
                            Button {
                                showPhotoLibrary = true
                            } label: {
                                Label("Photo Library", systemImage: "photo.on.rectangle")
                            }

                            Button {
                                showCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                            }

                            Button {
                                showDocumentPicker = true
                            } label: {
                                Label("Choose File", systemImage: "folder")
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.square")
                                Text("Select File to Upload")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }

                        // Image + OCR/Text/Table
                        if let image = selectedImage {
                            VStack(alignment: .leading, spacing: 16) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 220)
                                    .cornerRadius(12)
                                    .shadow(radius: 3)

                                // Mode toggle seeded by detection
                                HStack(spacing: 10) {
                                    Text("Parsed as:")
                                        .font(.system(size: 14, weight: .semibold))

                                    Picker("", selection: $parseMode) {
                                        Text("Text").tag(ParseMode.text)
                                        Text("Table").tag(ParseMode.table)
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(maxWidth: 260)

                                    if suggestedIsTable {
                                        Text("suggested")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .onChange(of: parseMode) { _ in
                                    // Re-parse when user toggles
                                    reparseCurrentImage()
                                }

                                Text(parseMode == .table ? "🧮 Table (TSV)" : "✏️ Extracted Text")
                                    .font(.system(size: 16, weight: .semibold))

                                TextEditor(text: $extractedText)
                                    .font(.system(size: 14))
                                    .frame(height: 180)
                                    .padding(8)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }
                            .padding(.horizontal)
                        }

                        // Save / Cancel
                        if !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack(spacing: 12) {
                                // Cancel
                                Button {
                                    extractedText = ""
                                    selectedImage = nil
                                    suggestedIsTable = false
                                    parseMode = .text
                                } label: {
                                    Label("Cancel", systemImage: "xmark.circle.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }

                                // Save (fileType follows parseMode)
                                Button {
                                    let fileType: DocFileType = (parseMode == .table) ? .spreadsheet : .text
                                    let doc = SavedDoc(id: UUID(),
                                                       title: "Untitled",
                                                       text: extractedText,
                                                       fileType: fileType)
                                    savedDocs.append(doc)
                                    extractedText = ""
                                    selectedImage = nil
                                    suggestedIsTable = false
                                    parseMode = .text
                                } label: {
                                    Label("Save as \(parseMode == .table ? "Spreadsheet" : "Document")",
                                          systemImage: "tray.and.arrow.down.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Docs Gallery
                        NavigationLink(destination: DocsGalleryView(savedDocs: $savedDocs)) {
                            Label("Docs Gallery", systemImage: "books.vertical.fill")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(.top, 10)
                        }

                        Spacer(minLength: 50)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }

        // Pickers / Camera
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePicker(sourceType: .photoLibrary) { image in
                handleNewImage(image)
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { image in
                handleNewImage(image)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CustomCameraView { croppedImage in
                handleNewImage(croppedImage)
            }
        }
    }

    // MARK: - Image handling / parsing

    private func handleNewImage(_ image: UIImage) {
        selectedImage = image
        extractedText = ""
        suggestedIsTable = false
        parseMode = .text

        // Seed suggestion using your TableDetector first (more reliable),
        // then fallback to plain text if no table found.
        if let detected = TableDetector.detect(from: image, mode: .fast),
           isGoodTable(detected.rows) {
            // looks like a real table → seed UI + content as table
            suggestedIsTable = true
            parseMode = .table
            extractedText = tsv(from: detected.rows)
        } else {
            // fallback to text
            parseAsText(image)
        }
    }

    private func reparseCurrentImage() {
        guard let image = selectedImage else { return }
        switch parseMode {
        case .table:
            // Try strong table parse; fallback to last known text if fails
            if let detected = TableDetector.detect(from: image, mode: .fast),
               isGoodTable(detected.rows) {
                extractedText = tsv(from: detected.rows)
            } else {
                extractedText = "No table detected. Try switching to Text."
            }
        case .text:
            parseAsText(image)
        }
    }

    private func parseAsText(_ image: UIImage) {
        guard let cg = image.cgImage else { return }
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        let req = VNRecognizeTextRequest { req, _ in
            let text = (req.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n") ?? ""
            DispatchQueue.main.async {
                self.extractedText = text
            }
        }
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        if #available(iOS 16.0, *) { req.revision = VNRecognizeTextRequestRevision3 }
        try? handler.perform([req])
    }

    // MARK: - Helpers

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
}
