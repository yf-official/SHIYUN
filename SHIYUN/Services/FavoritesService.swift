import Combine
import Foundation

@MainActor
final class FavoritesService: ObservableObject {
    private static let key = "favoritePoemIDs"
    private let defaults: UserDefaults
    @Published private(set) var ids: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ids = Set(defaults.stringArray(forKey: Self.key) ?? [])
    }

    func contains(_ poem: Poem) -> Bool { ids.contains(poem.id) }

    func toggle(_ poem: Poem) {
        if ids.contains(poem.id) { ids.remove(poem.id) }
        else { ids.insert(poem.id) }
        defaults.set(Array(ids).sorted(), forKey: Self.key)
    }

    func add(_ poemIDs: Set<String>) {
        ids.formUnion(poemIDs)
        defaults.set(Array(ids).sorted(), forKey: Self.key)
    }
}
