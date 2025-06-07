import Foundation

struct ProjectInfo: Identifiable, Codable {
    let id: UUID
    var name: String
    let createdDate: Date
    
    init(name: String = "") {
        self.id = UUID()
        self.name = name.isEmpty ? "Untitled Project" : name
        self.createdDate = Date()
    }
    
    mutating func rename(to newName: String) {
        self.name = newName.isEmpty ? "Untitled Project" : newName
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: createdDate)
    }
}
