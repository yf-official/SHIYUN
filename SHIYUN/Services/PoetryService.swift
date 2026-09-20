import Foundation

final class PoetryService {
    private struct SearchRecord {
        let poem: Poem
        let searchableText: String
    }

    struct ImportResult {
        let addedIDs: Set<String>
        let existingIDs: Set<String>
        let duplicateCount: Int
        let invalidCount: Int

        var collectionIDs: Set<String> { addedIDs.union(existingIDs) }
    }

    struct Diagnostics {
        let poemCount: Int
        let shuffleBagCount: Int
        let recentCount: Int
    }

    private struct Selection: Equatable {
        let tags: Set<String>
        let allowedIDs: Set<String>?
    }

    private static let personalPoemsKey = "personalPoems"
    private(set) var poems: [Poem] = []
    private(set) var sortedPoems: [Poem] = []
    private var poemByID: [String: Poem] = [:]
    private var searchRecords: [SearchRecord] = []
    private var shuffleBag: [Poem] = []
    private var activeSelection: Selection?
    private var recentIDs: [String] = []
    private let recentLimit = 60
    private let defaults: UserDefaults

    init(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        do {
            poems = try Self.load(from: bundle)
        } catch {
            NSLog("SHIYUN: unable to load poetry.json: %@", error.localizedDescription)
            poems = [Poem(id: "fallback", text: ["行到水穷处", "坐看云起时"], author: "王维", title: "终南别业", dynasty: "唐", tags: ["山水", "宁静"], mood: "calm", length: "short")]
        }
        if let data = defaults.data(forKey: Self.personalPoemsKey),
           let personal = try? JSONDecoder().decode([Poem].self, from: data) {
            mergePersonal(personal, persist: false)
        }
        rebuildLibraryIndexes()
    }

    static func load(from bundle: Bundle) throws -> [Poem] {
        guard let url = bundle.url(forResource: "poetry", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([Poem].self, from: Data(contentsOf: url))
    }

    func next(avoidingRecent: Bool = true, matching tags: Set<String> = [], allowedIDs: Set<String>? = nil) -> Poem {
        let selection = Selection(tags: tags, allowedIDs: allowedIDs?.isEmpty == false ? allowedIDs : nil)
        if shuffleBag.isEmpty || activeSelection != selection {
            var eligible = tags.isEmpty ? poems : poems.filter { !tags.isDisjoint(with: Set($0.tags)) }
            if let allowed = selection.allowedIDs {
                eligible = eligible.filter { allowed.contains($0.id) }
            }
            if eligible.isEmpty { eligible = poems }
            refillBag(from: eligible, avoidingRecent: avoidingRecent)
            activeSelection = selection
        }
        let poem = shuffleBag.removeLast()
        recentIDs.append(poem.id)
        if recentIDs.count > recentLimit { recentIDs.removeFirst(recentIDs.count - recentLimit) }
        return poem
    }

    func poem(id: String) -> Poem? { poemByID[id] }

    /// Searches the pre-sorted, pre-normalized library without rebuilding text or
    /// sorting results for every keystroke in the library window.
    func search(query: String, dynasty: String = "", author: String = "", allowedIDs: Set<String>? = nil) -> [Poem] {
        let needle = Self.normalizedSearchText(query)
        return searchRecords.compactMap { record in
            guard dynasty.isEmpty || record.poem.dynasty == dynasty else { return nil }
            guard author.isEmpty || record.poem.author == author else { return nil }
            guard allowedIDs == nil || allowedIDs!.contains(record.poem.id) else { return nil }
            guard needle.isEmpty || record.searchableText.contains(needle) else { return nil }
            return record.poem
        }
    }

    var diagnostics: Diagnostics {
        Diagnostics(poemCount: poems.count, shuffleBagCount: shuffleBag.count, recentCount: recentIDs.count)
    }

    @discardableResult
    func importPersonal(_ imported: [Poem]) -> Set<String> {
        importPersonalDetailed(imported).collectionIDs
    }

    func importPersonalDetailed(_ imported: [Poem]) -> ImportResult {
        var known: [String: String] = [:]
        for poem in poems { known[Self.contentKey(poem)] = poem.id }
        var seenIncoming: Set<String> = []
        var uniqueIncoming: [Poem] = []
        var existingIDs: Set<String> = []
        var duplicateCount = 0
        var invalidCount = 0

        for poem in imported {
            guard Self.isValid(poem) else {
                invalidCount += 1
                continue
            }
            let key = Self.contentKey(poem)
            if let existingID = known[key] {
                existingIDs.insert(existingID)
                duplicateCount += 1
                continue
            }
            if !seenIncoming.insert(key).inserted {
                duplicateCount += 1
                continue
            }
            uniqueIncoming.append(poem)
        }

        let addedIDs = mergePersonal(uniqueIncoming, persist: true)
        return ImportResult(
            addedIDs: addedIDs,
            existingIDs: existingIDs,
            duplicateCount: duplicateCount,
            invalidCount: invalidCount
        )
    }

    private static func isValid(_ poem: Poem) -> Bool {
        !poem.text.isEmpty && poem.text.count <= 2 && poem.text.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && !poem.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !poem.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !poem.dynasty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !contentKey(poem).isEmpty
    }

    private static func contentKey(_ poem: Poem) -> String {
        poem.text.joined().unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
            .lowercased()
    }

    @discardableResult
    private func mergePersonal(_ incoming: [Poem], persist: Bool) -> Set<String> {
        var personal = (defaults.data(forKey: Self.personalPoemsKey))
            .flatMap { try? JSONDecoder().decode([Poem].self, from: $0) } ?? []
        var importedIDs: Set<String> = []

        for poem in incoming {
            if let existing = poems.first(where: { Self.contentKey($0) == Self.contentKey(poem) }) {
                importedIDs.insert(existing.id)
                continue
            }
            let id = poems.contains(where: { $0.id == poem.id }) || poem.id.isEmpty ? "personal_\(UUID().uuidString.lowercased())" : poem.id
            let normalized = Poem(
                id: id,
                text: poem.text.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                author: poem.author.trimmingCharacters(in: .whitespacesAndNewlines),
                title: poem.title.trimmingCharacters(in: .whitespacesAndNewlines),
                dynasty: poem.dynasty.trimmingCharacters(in: .whitespacesAndNewlines),
                tags: poem.tags.isEmpty ? ["人生"] : poem.tags,
                mood: poem.mood.isEmpty ? "calm" : poem.mood,
                length: poem.length.isEmpty ? "short" : poem.length
            )
            poems.append(normalized)
            personal.append(normalized)
            importedIDs.insert(normalized.id)
        }

        if persist, let data = try? JSONEncoder().encode(personal) {
            defaults.set(data, forKey: Self.personalPoemsKey)
        }
        if !importedIDs.isEmpty { activeSelection = nil }
        if !importedIDs.isEmpty { rebuildLibraryIndexes() }
        return importedIDs
    }

    private func rebuildLibraryIndexes() {
        sortedPoems = poems.sorted { ($0.dynasty, $0.author, $0.title, $0.id) < ($1.dynasty, $1.author, $1.title, $1.id) }
        poemByID = Dictionary(uniqueKeysWithValues: poems.map { ($0.id, $0) })
        searchRecords = sortedPoems.map { poem in
            SearchRecord(
                poem: poem,
                searchableText: Self.normalizedSearchText(poem.text.joined() + poem.author + poem.title + poem.dynasty)
            )
        }
    }

    private static func normalizedSearchText(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .filter { !$0.isWhitespace && !$0.isPunctuation }
    }

    private func refillBag(from source: [Poem], avoidingRecent: Bool) {
        let recent = Set(recentIDs)
        var candidates = avoidingRecent ? source.filter { !recent.contains($0.id) } : source
        if candidates.isEmpty { candidates = source }
        shuffleBag = candidates.shuffled()
    }
}
