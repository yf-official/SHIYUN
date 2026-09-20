import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let shiyunCollection = UTType(exportedAs: "com.shiyun.poetry-collection", conformingTo: .json)
}

struct PoetryCollectionDocument: FileDocument {
    struct Payload: Codable {
        let format: String
        let version: Int
        let poems: [Poem]
    }

    static var readableContentTypes: [UTType] { [.shiyunCollection, .json] }
    static var writableContentTypes: [UTType] { [.json, .plainText] }

    var poems: [Poem]

    init(poems: [Poem] = []) {
        self.poems = poems
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(Payload.self, from: data) {
            poems = payload.poems
        } else {
            poems = try decoder.decode([Poem].self, from: data)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        if configuration.contentType.conforms(to: .plainText) {
            let text = poems.map(Self.plainTextLine).joined(separator: "\n") + (poems.isEmpty ? "" : "\n")
            guard let data = text.data(using: .utf8) else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
            return FileWrapper(regularFileWithContents: data)
        }
        let payload = Payload(format: "SHIYUN Poetry Collection", version: 2, poems: poems)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(payload))
    }

    static func plainTextLine(_ poem: Poem) -> String {
        let punctuation = CharacterSet(charactersIn: "，。！？；：,.!?;:")
        let lines = poem.text.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: punctuation) }
        let verse = lines.joined(separator: "，") + "。"
        return "\(verse)--\(poem.title)  \(poem.dynasty)·\(poem.author)"
    }

    static func read(from url: URL) throws -> PoetryCollectionDocument {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(Payload.self, from: data) {
            return PoetryCollectionDocument(poems: payload.poems)
        }
        return PoetryCollectionDocument(poems: try decoder.decode([Poem].self, from: data))
    }
}
