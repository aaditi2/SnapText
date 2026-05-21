import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var telemetry = TelemetryManager.shared
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    @State private var showDocumentPicker = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 4) { Image(systemName: "doc.text.viewfinder").resizable().frame(width: 36, height: 36).foregroundColor(.accentColor).padding(.bottom, 4); Text("SnapText").font(.system(size: 26, weight: .semibold)); Text("Capture. Extract. Edit.").font(.system(size: 14)).foregroundColor(.secondary) }
                            .padding(.top, 40)

                        Menu {
                            Button { showPhotoLibrary = true } label: { Label("Photo Library", systemImage: "photo.on.rectangle") }
                            Button { showCamera = true; telemetry.track(.cameraOpened) } label: { Label("Take Photo", systemImage: "camera") }
                            Button { showDocumentPicker = true } label: { Label("Choose File", systemImage: "folder") }
                        } label: { HStack { Image(systemName: "plus.square"); Text("Select File to Upload") }.font(.system(size: 15, weight: .medium)).padding(.vertical, 10).frame(maxWidth: .infinity).background(Color.blue).foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 10)).padding(.horizontal).shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2) }

                        if let image = viewModel.selectedImage { VStack(alignment: .leading, spacing: 16) {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220).cornerRadius(12).shadow(radius: 3)
                            HStack(spacing: 10) {
                                Text("Parsed as:").font(.system(size: 14, weight: .semibold))
                                Picker("", selection: $viewModel.parseMode) { Text("Text").tag(ContentViewModel.ParseMode.text); Text("Table").tag(ContentViewModel.ParseMode.table) }.pickerStyle(.segmented).frame(maxWidth: 260)
                                if viewModel.suggestedIsTable { Text("suggested").font(.caption).foregroundColor(.secondary) }
                            }.onChange(of: viewModel.parseMode) { _ in viewModel.reparseCurrentImage() }
                            Text(viewModel.parseMode == .table ? "🧮 Table (TSV)" : "✏️ Extracted Text").font(.system(size: 16, weight: .semibold))
                            TextEditor(text: $viewModel.extractedText).font(.system(size: 14)).frame(height: 180).padding(8).background(Color(.secondarySystemBackground)).cornerRadius(8)
                        }.padding(.horizontal) }

                        if viewModel.hasExtractedText { HStack(spacing: 12) {
                            Button { viewModel.cancelExtraction() } label: { Label("Cancel", systemImage: "xmark.circle.fill").font(.system(size: 15, weight: .semibold)).padding(.vertical, 10).frame(maxWidth: .infinity).background(Color.red).foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 10)) }
                            Button { viewModel.saveCurrentExtraction() } label: { Label("Save as \(viewModel.parseMode == .table ? "Spreadsheet" : "Document")", systemImage: "tray.and.arrow.down.fill").font(.system(size: 15, weight: .semibold)).padding(.vertical, 10).frame(maxWidth: .infinity).background(Color.green).foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 10)) }
                        }.padding(.horizontal) }

                        NavigationLink(destination: DocsGalleryView(savedDocs: $viewModel.savedDocs)) { Label("Docs Gallery", systemImage: "books.vertical.fill").font(.system(size: 15, weight: .medium)).foregroundColor(.blue).padding(.top, 10) }
                        NavigationLink(destination: TelemetryDebugView()) { Label("Telemetry Debug", systemImage: "waveform.path.ecg").font(.system(size: 14, weight: .medium)).foregroundColor(.teal) }
                        Spacer(minLength: 50)
                    }.padding(.bottom, 40)
                }
            }.navigationBarHidden(true)
        }
        .sheet(isPresented: $showPhotoLibrary) { ImagePicker(sourceType: .photoLibrary) { image in viewModel.handleNewImage(image, source: "photo_library") } }
        .sheet(isPresented: $showDocumentPicker) { DocumentPicker { image in viewModel.handleNewImage(image, source: "document_picker") } }
        .fullScreenCover(isPresented: $showCamera) { CustomCameraView { croppedImage in telemetry.track(.cropAdjusted); viewModel.handleNewImage(croppedImage, source: "camera") } }
    }
}
