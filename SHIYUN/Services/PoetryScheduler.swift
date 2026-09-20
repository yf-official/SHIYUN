import Combine
import Foundation

@MainActor
final class PoetryScheduler: ObservableObject {
    enum Phase { case blank, fadingIn, holding, fadingOut }

    @Published private(set) var current: Poem
    @Published private(set) var phase: Phase = .blank
    @Published private(set) var poemOpacity = 0.0

    private let service: PoetryService
    private let settings: AppSettings
    private let favorites: FavoritesService
    private var playbackTask: Task<Void, Never>?
    private var transitionRevision = 0
    private(set) var isRunning = false

    init(service: PoetryService, settings: AppSettings, favorites: FavoritesService) {
        self.service = service
        self.settings = settings
        self.favorites = favorites
        current = service.next()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleCycle(initialDelay: 0.7)
    }

    func stop() {
        guard isRunning || playbackTask != nil else { return }
        isRunning = false
        transitionRevision += 1
        playbackTask?.cancel()
        playbackTask = nil
    }

    func next() {
        playbackTask?.cancel()
        transitionRevision += 1
        let revision = transitionRevision
        playbackTask = Task { [weak self] in
            guard let self else { return }
            phase = .fadingOut
            poemOpacity = 0
            try? await Task.sleep(for: .seconds(0.65))
            guard !Task.isCancelled, revision == transitionRevision else { return }
            current = nextPoem()
            phase = .fadingIn
            poemOpacity = 1
            if isRunning { scheduleHoldAndContinue() }
        }
    }

    private func scheduleCycle(initialDelay: Double) {
        playbackTask?.cancel()
        transitionRevision += 1
        let revision = transitionRevision
        playbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(initialDelay))
            guard !Task.isCancelled, let self, revision == transitionRevision else { return }
            current = nextPoem()
            phase = .fadingIn
            poemOpacity = 1
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            phase = .holding
            try? await Task.sleep(for: .seconds(randomHoldDuration()))
            guard !Task.isCancelled else { return }
            phase = .fadingOut
            poemOpacity = 0
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            phase = .blank
            try? await Task.sleep(for: .seconds(randomBlankDuration()))
            guard !Task.isCancelled else { return }
            scheduleCycle(initialDelay: 0)
        }
    }

    private func scheduleHoldAndContinue() {
        transitionRevision += 1
        let revision = transitionRevision
        playbackTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, revision == transitionRevision else { return }
            phase = .holding
            try? await Task.sleep(for: .seconds(randomHoldDuration()))
            guard !Task.isCancelled else { return }
            phase = .fadingOut
            poemOpacity = 0
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            phase = .blank
            try? await Task.sleep(for: .seconds(randomBlankDuration()))
            guard !Task.isCancelled else { return }
            scheduleCycle(initialDelay: 0)
        }
    }

    private func nextPoem() -> Poem {
        let allowed = settings.poetryScope == .favorites ? favorites.ids : nil
        return service.next(avoidingRecent: settings.avoidRecent, allowedIDs: allowed)
    }

    private func randomHoldDuration() -> Double {
        if settings.pace == .custom {
            return Double.random(in: (settings.customHoldDuration * 0.9)...(settings.customHoldDuration * 1.1))
        }
        return Double.random(in: settings.pace.holdRange)
    }

    private func randomBlankDuration() -> Double {
        if settings.pace == .custom {
            return Double.random(in: (settings.customBlankDuration * 0.9)...(settings.customBlankDuration * 1.1))
        }
        return Double.random(in: settings.pace.blankRange)
    }
}
