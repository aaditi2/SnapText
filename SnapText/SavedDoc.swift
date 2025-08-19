import Foundation

enum DocFileType: String, Codable {
    case text
    case spreadsheet
}

struct SavedDoc: Identifiable, Codable {
    var id: UUID
    var title: String
    var text: String
    var fileType: DocFileType
}
