import SwiftUI

struct EditableDocView: View {
    @Binding var doc: SavedDoc

    var body: some View {
        VStack {
            TextEditor(text: $doc.text)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.gray.opacity(0.2)))
        }
        .padding()
        .navigationTitle("Edit Document")
    }
}
