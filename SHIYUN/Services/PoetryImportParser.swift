import Foundation

enum PoetryImportError: LocalizedError {
    case unsupportedFormat
    case missingColumns
    case noPoems

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "不支持此文件格式。请选择 JSON、CSV 或 TXT 文件。"
        case .missingColumns: return "CSV 至少需要 text（诗句）列；可选 author、title、dynasty、tags。"
        case .noPoems: return "文件中没有找到可导入的诗句。"
        }
    }
}

enum PoetryImportParser {
    private struct FlexiblePoem: Decodable {
        let id: String?
        let text: [String]
        let author: String?
        let title: String?
        let dynasty: String?
    }

    private struct FlexiblePayload: Decodable {
        let poems: [FlexiblePoem]
    }

    static func parse(url: URL) throws -> [Poem] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let ext = url.pathExtension.lowercased()

        if ext == "json" || ext == "shiyun" || ext.isEmpty {
            if let poems = try? parseJSON(data), !poems.isEmpty { return poems }
            if ext == "json" || ext == "shiyun" { throw PoetryImportError.noPoems }
        }
        guard let source = String(data: data, encoding: .utf8) else { throw PoetryImportError.unsupportedFormat }
        let poems: [Poem]
        switch ext {
        case "csv": poems = try parseCSV(source)
        case "txt": poems = parseText(source)
        default: throw PoetryImportError.unsupportedFormat
        }
        guard !poems.isEmpty else { throw PoetryImportError.noPoems }
        return poems
    }

    static func parseJSON(_ data: Data) throws -> [Poem] {
        let decoder = JSONDecoder()
        if let payload = try? decoder.decode(PoetryCollectionDocument.Payload.self, from: data) {
            return payload.poems
        }
        if let poems = try? decoder.decode([Poem].self, from: data) { return poems }
        let flexible: [FlexiblePoem]
        if let payload = try? decoder.decode(FlexiblePayload.self, from: data) {
            flexible = payload.poems
        } else {
            flexible = try decoder.decode([FlexiblePoem].self, from: data)
        }
        return flexible.map {
            Poem(
                id: $0.id ?? "personal_\(UUID().uuidString.lowercased())",
                text: Array($0.text.prefix(2)),
                author: $0.author?.nonEmpty ?? "佚名",
                title: $0.title?.nonEmpty ?? "私人诗选",
                dynasty: $0.dynasty?.nonEmpty ?? "未详",
                tags: ["自选"], mood: "calm", length: "short"
            )
        }
    }

    static func parseCSV(_ source: String) throws -> [Poem] {
        let rows = csvRows(source).filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        guard let first = rows.first else { throw PoetryImportError.noPoems }
        let headers = first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\u{feff}", with: "").lowercased() }
        func index(_ names: Set<String>) -> Int? { headers.firstIndex { names.contains($0) } }
        guard let textIndex = index(["text", "verse", "诗句", "正文", "内容"]) else { throw PoetryImportError.missingColumns }
        let authorIndex = index(["author", "作者"])
        let titleIndex = index(["title", "诗名", "标题", "出处"])
        let dynastyIndex = index(["dynasty", "朝代"])
        let tagsIndex = index(["tags", "标签"])

        return rows.dropFirst().compactMap { row in
            guard textIndex < row.count else { return nil }
            let lines = poemLines(row[textIndex])
            guard !lines.isEmpty else { return nil }
            return makePoem(
                lines: lines,
                author: value(row, at: authorIndex, fallback: "佚名"),
                title: value(row, at: titleIndex, fallback: "私人诗选"),
                dynasty: value(row, at: dynastyIndex, fallback: "未详"),
                tags: splitTags(value(row, at: tagsIndex, fallback: "自选"))
            )
        }
    }

    static func parseText(_ source: String) -> [Poem] {
        source.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .compactMap(parseTextBlock)
    }

    private static func parseTextBlock(_ block: String) -> Poem? {
        let rows = block.split(whereSeparator: \.isNewline).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !rows.isEmpty else { return nil }

        if rows.count == 1, let exported = parseExportedLine(rows[0]) { return exported }

        var keyed: [String: String] = [:]
        for row in rows {
            let parts = row.split(separator: "：", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                keyed[parts[0].lowercased()] = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }
        if let text = keyed["诗句"] ?? keyed["正文"] ?? keyed["text"] {
            return makePoem(
                lines: poemLines(text),
                author: keyed["作者"] ?? keyed["author"] ?? "佚名",
                title: keyed["诗名"] ?? keyed["标题"] ?? keyed["title"] ?? "私人诗选",
                dynasty: keyed["朝代"] ?? keyed["dynasty"] ?? "未详",
                tags: splitTags(keyed["标签"] ?? keyed["tags"] ?? "自选")
            )
        }

        var verseRows = rows
        var metadata = ["佚名", "私人诗选", "未详", "自选"]
        if let last = rows.last {
            let fields = last.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            if fields.count >= 3 {
                verseRows.removeLast()
                for index in 0..<min(fields.count, metadata.count) where !fields[index].isEmpty { metadata[index] = fields[index] }
            }
        }
        let lines = verseRows.flatMap(poemLines)
        guard !lines.isEmpty else { return nil }
        return makePoem(lines: lines, author: metadata[0], title: metadata[1], dynasty: metadata[2], tags: splitTags(metadata[3]))
    }

    private static func parseExportedLine(_ line: String) -> Poem? {
        let halves = line.components(separatedBy: "--")
        guard halves.count == 2 else { return nil }
        let metadata = halves[1].components(separatedBy: "  ").filter { !$0.isEmpty }
        guard metadata.count >= 2 else { return nil }
        let origin = metadata.last!.split(separator: "·", maxSplits: 1).map(String.init)
        guard origin.count == 2 else { return nil }
        let verse = halves[0].trimmingCharacters(in: CharacterSet(charactersIn: "。 "))
        let lines = verse.components(separatedBy: "，").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return makePoem(lines: lines, author: origin[1], title: metadata.dropLast().joined(separator: "  "), dynasty: origin[0], tags: ["自选"])
    }

    private static func makePoem(lines: [String], author: String, title: String, dynasty: String, tags: [String]) -> Poem {
        Poem(
            id: "personal_\(UUID().uuidString.lowercased())",
            text: Array(lines.prefix(2)),
            author: author,
            title: title,
            dynasty: dynasty,
            tags: tags,
            mood: "calm",
            length: "short"
        )
    }

    private static func poemLines(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\\n", with: "\n")
            .split(whereSeparator: { $0.isNewline || $0 == "/" || $0 == "／" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func splitTags(_ text: String) -> [String] {
        let values = text.split(whereSeparator: { ",;，；、".contains($0) }).map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return values.isEmpty ? ["自选"] : values
    }

    private static func value(_ row: [String], at index: Int?, fallback: String) -> String {
        guard let index, index < row.count else { return fallback }
        let result = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? fallback : result
    }

    private static func csvRows(_ source: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        let characters = Array(source)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                if quoted, index + 1 < characters.count, characters[index + 1] == "\"" {
                    field.append("\"")
                    index += 1
                } else {
                    quoted.toggle()
                }
            } else if character == ",", !quoted {
                row.append(field)
                field = ""
            } else if character == "\n", !quoted {
                row.append(field.trimmingCharacters(in: CharacterSet(charactersIn: "\r")))
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(character)
            }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
