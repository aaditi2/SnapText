import SwiftUI
import VisionKit
import Vision

struct ContentView: View {
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var extractedText: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("SnapText")
                .font(.largeTitle)
                .bold()
                .padding(.top)

            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
            }

            Button(action: {
                showImagePicker = true
            }) {
                Text("Open Camera")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 200)
                    .background(Color.blue)
                    .cornerRadius(12)
            }

            if !extractedText.isEmpty {
                Text("Extracted Text:")
                    .font(.headline)
                    .padding(.top)

                ScrollView {
                    Text(extractedText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .padding()
            }

            Spacer()
        }
        .fullScreenCover(isPresented: $showImagePicker) {
            ImagePicker(sourceType: .camera) { image in
                self.selectedImage = image
                recognizeText(from: image)
            }
        }
    }

    private func recognizeText(from image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { (request, error) in
            if let results = request.results as? [VNRecognizedTextObservation] {
                let text = results.compactMap {
                    $0.topCandidates(1).first?.string
                }.joined(separator: "\n")
                DispatchQueue.main.async {
                    self.extractedText = text
                }
            }
        }

        request.recognitionLevel = .accurate
        try? handler.perform([request])
    }
}
