import Foundation

struct UserPoem: Identifiable, Equatable {
    let id: String
    var title: String
    var body: String
    let createdAt: Date
    var updatedAt: Date
}
