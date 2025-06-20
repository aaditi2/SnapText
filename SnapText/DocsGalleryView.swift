import SwiftUI

struct DocsGalleryView: View {
    @Binding var savedDocs: [SavedDoc]

    var body: some View {
        List {
            ForEach(savedDocs) { doc in
                NavigationLink(destination: EditableDocView(doc: doc, savedDocs: $savedDocs)) {
                    Text(doc.text.prefix(30) + (doc.text.count > 30 ? "..." : ""))
                        .lineLimit(1)
                }
            }
        }
        .navigationTitle("📂 Docs Gallery")
    }
}
