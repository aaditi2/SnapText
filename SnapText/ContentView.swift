import SwiftUI
import Vision
import VisionKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showUploadOptions = false
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    @State private var selectedImage: UIImage?
    @State private var extractedText: String = ""
    @State private var savedDocs: [SavedDoc] = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // App Header
                    Text("📄 SnapText")
                        .font(.system(size: 38, weight: .bold, design: .rounded))

                    Text("Capture. Extract. Edit. ")
                        .font(.title3)
                        .foregroundColor(.gray)

                    // Upload Button (styled)
                    Menu {
                        Button {
                            showPhotoLibrary = true
                        } label: {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                        }

                        Button {
                            showCamera = true
                        } label: {
                            Label("Take Photo or Video", systemImage: "camera")
                        }

                        Button {
                            showDocumentPicker = true
                        } label: {
                            Label("Choose File", systemImage: "folder")
                        }
                    } label: {
                        Label("Select File to Upload", systemImage: "plus.square")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.9))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 20)
                    }

                    // Show selected image
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(12)

                        Text("✏️ Extracted Text")
                            .font(.title2)
                            .fontWeight(.semibold)

                        TextEditor(text: $extractedText)
                            .padding()
                            .frame(height: 200)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }

                    // Save Button
                    if !extractedText.isEmpty {
                        Button("💾 Save as Document") {
                            let doc = SavedDoc(id: UUID(), title: "Untitled", text: extractedText)
                            savedDocs.append(doc)
                            extractedText = ""
                            selectedImage = nil
                        }
                        .font(.headline)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 25)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .shadow(radius: 5)
                    }

                    // Link to Saved Documents
                    NavigationLink("📚 Docs Gallery") {
                        DocsGalleryView(savedDocs: $savedDocs)
                    }
                    .font(.headline)
                    .padding(.top, 20)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }

        // Upload Sheet Handling
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePicker(sourceType: .photoLibrary) { image in
                handleImage(image)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            Camera { image in handleImage(image) }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { image in
                handleImage(image)
            }
        }
    }

    // OCR
    private func handleImage(_ image: UIImage) {
        self.selectedImage = image
        guard let cgImage = image.cgImage else { return }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, _ in
            if let results = request.results as? [VNRecognizedTextObservation] {
                let text = results.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                self.extractedText = text
            }
        }

        request.recognitionLevel = .accurate
        try? requestHandler.perform([request])
    }
}
