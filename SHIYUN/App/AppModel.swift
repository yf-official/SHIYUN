import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let settings: AppSettings
    let poetry: PoetryService
    let favorites: FavoritesService
    let background: BackgroundService
    let creative: CreativePoetryService
    let scheduler: PoetryScheduler
    private var cancellables = Set<AnyCancellable>()

    init() {
        AppCachePolicy.enforce()
        let settings = AppSettings()
        let poetry = PoetryService()
        let favorites = FavoritesService()
        let background = BackgroundService()
        let creative = CreativePoetryService()
        self.settings = settings
        self.poetry = poetry
        self.favorites = favorites
        self.background = background
        self.creative = creative
        scheduler = PoetryScheduler(service: poetry, settings: settings, favorites: favorites)
        settings.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.objectWillChange.send() }
            }
            .store(in: &cancellables)
    }
}
