import Foundation

struct SavedDoc: Identifiable, Codable {
    var id: UUID
    var title: String
    var text: String
}
