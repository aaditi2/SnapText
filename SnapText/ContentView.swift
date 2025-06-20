import SwiftUI
import Vision
import VisionKit
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isCameraPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var isDocumentPickerPresented = false
    @State private var extractedText: String = ""
    @State private var showTextEditor = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showMenu = false

    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                Text("📸 SnapText")
                    .font(.system(size: 38, weight: .bold, design: .rounded))

                Button(action: {
                    showMenu.toggle()
                }) {
                    Text("Upload from...")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                if showMenu {
                    VStack(spacing: 12) {
                        Button("Camera") { isCameraPresented = true }
                        Button("Gallery") { isPhotoPickerPresented = true }
                        Button("Drive") { isDocumentPickerPresented = true }
                    }
                    .padding(.horizontal)
                }

                if showTextEditor {
                    Text("📝 Extracted Text:")
                        .font(.headline)
                        .padding(.top)

                    TextEditor(text: $extractedText)
                        .frame(height: 250)
                        .padding()
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))
                }
            }
            .padding()
            .photosPicker(isPresented: $isPhotoPickerPresented, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { newItem in
                if let item = newItem {
                    item.loadTransferable(type: Data.self) { result in
                        switch result {
                        case .success(let data):
                            if let data = data, let uiImage = UIImage(data: data) {
                                recognizeText(from: uiImage)
                            }
                        default: break
                        }
                    }
                }
            }
            .sheet(isPresented: $isDocumentPickerPresented) {
                DocumentPicker { image in
                    recognizeText(from: image)
                }
            }
            .fullScreenCover(isPresented: $isCameraPresented) {
                Camera { image in
                    recognizeText(from: image)
                }
            }
        }
    }

    func recognizeText(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else { return }
            let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            DispatchQueue.main.async {
                extractedText = text
                showTextEditor = true
            }
        }

        request.recognitionLevel = .accurate
        try? requestHandler.perform([request])
    }
}
