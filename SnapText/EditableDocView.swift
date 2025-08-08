import SwiftUI

struct EditableDocView: View {
    @Binding var doc: SavedDoc
    @State private var showExportSheet = false
    @State private var exportURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            // Editable title field
            TextField("Title", text: $doc.title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal)
                .padding(.top, 20)

            // Optional timestamp
            Text(formattedDate())
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom, 12)

            // Main note editor
            TextEditor(text: $doc.text)
                .font(.system(size: 17))
                .foregroundColor(.white)
                .padding(.horizontal)
                .scrollContentBackground(.hidden)
                .frame(maxHeight: .infinity)

            Divider()

            // Bottom toolbar (like Apple Notes)
            HStack(spacing: 30) {
                Image(systemName: "checklist")
                Button {
                    if let url = ExportService.exportTextAsPDF(doc.text) {
                        exportURL = url
                        showExportSheet = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            .font(.system(size: 20, weight: .medium))
            .padding()
            .foregroundColor(.yellow)
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showExportSheet) {
            if let fileURL = exportURL {
                ShareSheet(activityItems: [fileURL])
            }
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}
