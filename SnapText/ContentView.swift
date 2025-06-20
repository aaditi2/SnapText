import SwiftUI
import VisionKit
import Vision

struct ContentView: View {
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showDocumentPicker = false
    @State private var extractedText: String = ""
    @State private var selectedImage: UIImage?
    @State private var savedDocs: [SavedDoc] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("SnapText")
                    .font(.largeTitle)
                    .bold()

                HStack(spacing: 20) {
                    Button("📷 Camera") { showCamera = true }
                    Button("🖼️ Gallery") { showPhotoLibrary = true }
                    Button("📁 Drive") { showDocumentPicker = true }
                }

                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                }

                TextEditor(text: $extractedText)
                    .frame(height: 150)
                    .border(Color.gray)

                if !extractedText.isEmpty {
                    Button("💾 Save as Document") {
                        let doc = SavedDoc(id: UUID(), text: extractedText)
                        savedDocs.append(doc)
                        extractedText = ""
                        selectedImage = nil
                    }
                }

                NavigationLink("🗂️ Docs Gallery", destination: DocsGalleryView(savedDocs: $savedDocs))

                Spacer()
            }
            .fullScreenCover(isPresented: $showCamera) {
                Camera { image in
                    handleImage(image)
                }
            }
            .sheet(isPresented: $showPhotoLibrary) {
                ImagePicker(sourceType: .photoLibrary) { image in handleImage(image) }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { image in handleImage(image) }
            }
            .padding()
        }
    }

    func handleImage(_ image: UIImage) {
        selectedImage = image
        extractText(from: image)
    }

    func extractText(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        let request = VNRecognizeTextRequest { request, error in
            if let observations = request.results as? [VNRecognizedTextObservation] {
                DispatchQueue.main.async {
                    extractedText = observations
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
}

struct SavedDoc: Identifiable, Codable {
    let id: UUID
    var text: String
}
