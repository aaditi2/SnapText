import SwiftUI

struct DocsGalleryView: View {
    @Binding var savedDocs: [SavedDoc]

    var body: some View {
        List {
            ForEach($savedDocs) { $doc in
                NavigationLink(destination: EditableDocView(doc: $doc)) {
                    Text(doc.text.prefix(30) + "...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .navigationTitle("📚 Docs Gallery")
    }
}
