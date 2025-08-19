import SwiftUI

struct EditableDocView: View {
    @Binding var doc: SavedDoc
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showExportOptions = false

    var body: some View {
        VStack(spacing: 0) {

            // Title editor inside the content (still editable)
            TextField("Title", text: $doc.title)
                .font(.system(size: 22, weight: .semibold))
                .padding(.horizontal)
                .padding(.top, 12)

            // Timestamp
            Text(formattedDate())
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom, 12)

            // Main editor
            Group {
                if doc.fileType == .spreadsheet {
                    TableEditor(text: $doc.text)
                        .font(.system(size: 17))
                        .padding(.horizontal)
                        .frame(maxHeight: .infinity)
                } else {
                    TextEditor(text: $doc.text)
                        .font(.system(size: 17))
                        .padding(.horizontal)
                        .scrollContentBackground(.hidden)
                        .frame(maxHeight: .infinity)
                }
            }

            Divider()

            // Toolbar
            HStack(spacing: 30) {
                Button(action: { showExportOptions = true }) {
                    Image(systemName: "square.and.arrow.up")
                        .imageScale(.large)
                }
            }
            .font(.system(size: 20, weight: .medium))
            .padding()
            .foregroundColor(.yellow)
        }
        // Use nav bar for the title so Back shows “Docs Gallery”
        .navigationTitle(doc.title.isEmpty ? "Untitled" : doc.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .preferredColorScheme(.dark)

        // Share + export
        .sheet(isPresented: $showExportSheet) {
            if let fileURL = exportURL {
                ShareSheet(activityItems: [fileURL])
            }
        }
        .confirmationDialog("Export", isPresented: $showExportOptions, titleVisibility: .visible) {
            switch doc.fileType {
            case .text:
                Button("Export as PDF") {
                    if let url = ExportService.exportTextAsPDF(doc.text) {
                        exportURL = url
                        showExportSheet = true
                    }
                }
            case .spreadsheet:
                Button("Export as XLS") {
                    if let url = ExportService.exportTextAsXLS(doc.text) {
                        exportURL = url
                        showExportSheet = true
                    }
                }
            }
        }
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: Date())
    }
}
