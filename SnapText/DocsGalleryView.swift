import SwiftUI

struct DocsGalleryView: View {
    @Binding var savedDocs: [SavedDoc]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach($savedDocs) { $doc in
                    NavigationLink(destination: EditableDocView(doc: $doc)) {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(doc.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                Text(currentDateString())
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)

                                HStack(spacing: 4) {
                                    Image(systemName: doc.fileType == .spreadsheet ? "tablecells" : "doc.text")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                    Text(doc.fileType == .spreadsheet ? "Spreadsheet" : "Document")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                            }

                            Spacer()

                            HStack {
                                    Spacer()
                                    Text("View Details →")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                                .padding(.top, 49)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(14)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Docs Gallery")
            .background(Color(.systemGroupedBackground))
        }

    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
}
