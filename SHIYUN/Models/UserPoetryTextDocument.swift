import SwiftUI
import UniformTypeIdentifiers

struct UserPoetryTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    static var writableContentTypes: [UTType] { [.plainText] }

    var poems: [UserPoem]

    init(poems: [UserPoem] = []) {
        self.poems = poems
    }

    init(configuration: ReadConfiguration) throws {
        poems = []
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let text = poems.map { poem in
            "《\(poem.title)》\n\(poem.body)"
        }.joined(separator: "\n\n") + (poems.isEmpty ? "" : "\n")
        guard let data = text.data(using: .utf8) else { throw CocoaError(.fileWriteInapplicableStringEncoding) }
        return FileWrapper(regularFileWithContents: data)
    }
}
