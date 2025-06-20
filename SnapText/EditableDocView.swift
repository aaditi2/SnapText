import SwiftUI

struct EditableDocView: View {
    var doc: SavedDoc
    @Binding var savedDocs: [SavedDoc]
    @State private var text: String

    init(doc: SavedDoc, savedDocs: Binding<[SavedDoc]>) {
        self.doc = doc
        self._savedDocs = savedDocs
        self._text = State(initialValue: doc.text)
    }

    var body: some View {
        VStack {
            TextEditor(text: $text)
                .padding()
                .border(Color.gray)
                .frame(maxHeight: .infinity)

            Button("💾 Save Changes") {
                if let index = savedDocs.firstIndex(where: { $0.id == doc.id }) {
                    savedDocs[index].text = text
                }
            }
            .padding()
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("📝 Edit Doc")
        .padding()
    }
}
