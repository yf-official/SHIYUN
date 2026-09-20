import Foundation

struct Poem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let text: [String]
    let author: String
    let title: String
    let dynasty: String
    let tags: [String]
    let mood: String
    let length: String

    var accessibilityText: String {
        text.joined(separator: "，") + "。\(dynasty)，\(author)，《\(title)》。"
    }
}

enum PoetryLayout: String, CaseIterable, Identifiable {
    case horizontal
    case vertical
    var id: String { rawValue }
}
