import SwiftUI

struct TableEditor: View {
    @Binding var text: String
    @State private var data: [[String]]

    init(text: Binding<String>) {
        self._text = text
        self._data = State(initialValue: text.wrappedValue
            .split(separator: "\n")
            .map { $0.split(separator: "\t").map(String.init) })
    }

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(data.indices, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(data[row].indices, id: \.self) { col in
                            TextField("", text: bindingForCell(row: row, col: col))
                                .frame(minWidth: 80, minHeight: 30)
                                .padding(4)
                                .background(Color(.secondarySystemBackground))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .onChange(of: data) { _ in
            text = data.map { $0.joined(separator: "\t") }.joined(separator: "\n")
        }
    }

    private func bindingForCell(row: Int, col: Int) -> Binding<String> {
        Binding(
            get: { data[row][col] },
            set: { data[row][col] = $0 }
        )
    }
}
