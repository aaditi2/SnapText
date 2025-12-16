import SwiftUI

struct TableEditor: View {
    @Binding var text: String
    @State private var data: [[String]]

    private let minCellWidth: CGFloat = 140
    private let rowHeight: CGFloat = 44

    init(text: Binding<String>) {
        _text = text
        let grid = text.wrappedValue
            .split(separator: "\n")
            .map { $0.split(separator: "\t").map(String.init) }
        _data = State(initialValue: grid.isEmpty ? [[""]] : grid)
    }

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(spacing: 1) {
                ForEach(data.indices, id: \.self) { r in
                    HStack(spacing: 1) {
                        ForEach(0..<maxColumns, id: \.self) { c in
                            let binding = Binding(
                                get: { safeCell(r, c) },
                                set: { setCell(r, c, $0) }
                            )
                            TextField("", text: binding)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .font(.system(size: 16, weight: r == 0 ? .semibold : .regular))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .frame(minWidth: minCellWidth, minHeight: rowHeight, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.25), lineWidth: 1))
                        }
                    }
                }
            }
            .padding(6)
        }
        .background(Color.black.opacity(0.05))
        .onChange(of: data) { _ in
            text = data.map { $0.joined(separator: "\t") }.joined(separator: "\n")
        }
    }

    private var maxColumns: Int {
        data.map { $0.count }.max() ?? 1
    }

    private func safeCell(_ r: Int, _ c: Int) -> String {
        (r < data.count && c < data[r].count) ? data[r][c] : ""
    }

    private func setCell(_ r: Int, _ c: Int, _ val: String) {
        if r >= data.count { return }
        while c >= data[r].count { data[r].append("") }
        data[r][c] = val
    }
}
