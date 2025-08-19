import SwiftUI
import Vision
import VisionKit
import UniformTypeIdentifiers
import CoreGraphics

// Wrapper for Identifiable UIImage
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ContentView: View {
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    @State private var selectedImage: UIImage?
    @State private var extractedText: String = ""
    @State private var savedDocs: [SavedDoc] = []

    @State private var pendingImageForCropping: IdentifiableImage?
    @State private var isTableDetected = false

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
                        
                        // Image + OCR Text Display
                        if let image = selectedImage {
                            VStack(alignment: .leading, spacing: 16) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 220)
                                    .cornerRadius(12)
                                    .shadow(radius: 3)
                                
                                Text("✏️ Extracted Text")
                                    .font(.system(size: 16, weight: .semibold))
                                
                                TextEditor(text: $extractedText)
                                    .font(.system(size: 14))
                                    .frame(height: 180)
                                    .padding(8)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Save Button
                        if !extractedText.isEmpty {
                            Button(action: {
                                let fileType: DocFileType = isTableDetected ? .spreadsheet : .text
                                let doc = SavedDoc(id: UUID(), title: "Untitled", text: extractedText, fileType: fileType)
                                savedDocs.append(doc)
                                extractedText = ""
                                selectedImage = nil
                                isTableDetected = false
                            }) {
                                HStack {
                                    Image(systemName: "tray.and.arrow.down.fill")
                                    Text("Save as Document")
                                }
                                .font(.system(size: 15, weight: .medium))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 20)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                            }
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
        
        // Image Pickers
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePicker(sourceType: .photoLibrary) { image in
                handleImage(image)
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { image in
                handleImage(image)
            }
        }
        
        // Camera Capture → Crop
        .fullScreenCover(isPresented: $showCamera) {
            CustomCameraView { croppedImage in
                handleImage(croppedImage)
            }
        }
    }

    // OCR
    private func handleImage(_ image: UIImage) {
        self.selectedImage = image
        guard let cgImage = image.cgImage else { return }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, _ in
            guard let results = request.results as? [VNRecognizedTextObservation] else { return }

            let sorted = results.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            var rows: [[VNRecognizedTextObservation]] = []
            let threshold: CGFloat = 0.02
            for obs in sorted {
                if var last = rows.last, let first = last.first,
                   abs(obs.boundingBox.midY - first.boundingBox.midY) < threshold {
                    last.append(obs)
                    rows[rows.count - 1] = last
                } else {
                    rows.append([obs])
                }
            }

            // Sort observations in each row from left to right
            let columnsPerRow = rows.map { row in
                row.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            }

            // Determine if a tabular structure exists by checking
            // for consistent column alignment across multiple rows
            let tolerance: CGFloat = 0.02
            var alignedRowCount = 0
            if let firstRow = columnsPerRow.first, firstRow.count > 1 {
                alignedRowCount = 1
                for row in columnsPerRow.dropFirst() {
                    guard row.count == firstRow.count else { continue }
                    let aligns = zip(row, firstRow).allSatisfy { abs($0.boundingBox.midX - $1.boundingBox.midX) < tolerance }
                    if aligns { alignedRowCount += 1 }
                }
            }

            let isTable = alignedRowCount >= 2
            if isTable {
                let tableString = columnsPerRow.map { row in
                    row.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\t")
                }.joined(separator: "\n")
                self.extractedText = tableString
                self.isTableDetected = true
            } else {
                let text = results.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                self.extractedText = text
                self.isTableDetected = false
            }
        }

        request.recognitionLevel = .accurate
        try? requestHandler.perform([request])
    }
}
