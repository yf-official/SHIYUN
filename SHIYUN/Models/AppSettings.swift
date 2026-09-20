import AppKit
import Combine
import ServiceManagement
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, zhHans, english
    var id: String { rawValue }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
}

enum AmbientBackgroundMode: String, CaseIterable, Identifiable {
    case atmosphere, color, image
    var id: String { rawValue }
}

enum PoetryFontStyle: String, CaseIterable, Identifiable {
    case song, kai, modern, hei, fangSong, yuan, liSong, weiBei, lanTing
    var id: String { rawValue }
}

struct PoetryRGBA: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let warmInk = PoetryRGBA(red: 0.22, green: 0.20, blue: 0.18, alpha: 1)
    static let warmPaper = PoetryRGBA(red: 0.94, green: 0.93, blue: 0.89, alpha: 1)
    var color: Color { Color(red: red, green: green, blue: blue, opacity: alpha) }
}

enum PlaybackPace: String, CaseIterable, Identifiable {
    case relaxed, standard, brisk, custom
    var id: String { rawValue }

    var holdRange: ClosedRange<Double> {
        switch self {
        case .relaxed: return 28...42
        case .standard: return 18...32
        case .brisk: return 12...20
        case .custom: return 18...32
        }
    }

    var blankRange: ClosedRange<Double> {
        switch self {
        case .relaxed: return 5...9
        case .standard: return 3...7
        case .brisk: return 2...5
        case .custom: return 3...7
        }
    }
}

enum PoetryScope: String, CaseIterable, Identifiable {
    case all, favorites
    var id: String { rawValue }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let language = "language"
        static let appearance = "appearance"
        static let fontStyle = "fontStyle"
        static let fontSize = "fontSize"
        static let pace = "pace"
        static let showAuthor = "showAuthor"
        static let showTitle = "showTitle"
        static let showDynasty = "showDynasty"
        static let avoidRecent = "avoidRecent"
        static let layout = "layout"
        static let menuBar = "menuBar"
        static let poetryScope = "poetryScope"
        static let automaticPoetryColor = "automaticPoetryColor"
        static let poetryColor = "poetryColor"
        static let customHoldDuration = "customHoldDuration"
        static let customBlankDuration = "customBlankDuration"
        static let backgroundMode = "backgroundMode"
        static let backgroundColor = "backgroundColor"
        static let backgroundImageDim = "backgroundImageDim"
    }

    private let defaults: UserDefaults

    @Published var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: Key.language) } }
    var appearance: AppearanceMode {
        didSet {
            defaults.set(appearance.rawValue, forKey: Key.appearance)
            DispatchQueue.main.async { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }
    @Published var fontStyle: PoetryFontStyle { didSet { defaults.set(fontStyle.rawValue, forKey: Key.fontStyle) } }
    @Published var fontSize: Double { didSet { defaults.set(fontSize, forKey: Key.fontSize) } }
    @Published var pace: PlaybackPace { didSet { defaults.set(pace.rawValue, forKey: Key.pace) } }
    @Published var showAuthor: Bool { didSet { defaults.set(showAuthor, forKey: Key.showAuthor) } }
    @Published var showTitle: Bool { didSet { defaults.set(showTitle, forKey: Key.showTitle) } }
    @Published var showDynasty: Bool { didSet { defaults.set(showDynasty, forKey: Key.showDynasty) } }
    @Published var avoidRecent: Bool { didSet { defaults.set(avoidRecent, forKey: Key.avoidRecent) } }
    @Published var layout: PoetryLayout { didSet { defaults.set(layout.rawValue, forKey: Key.layout) } }
    @Published var showMenuBar: Bool { didSet { defaults.set(showMenuBar, forKey: Key.menuBar) } }
    @Published var poetryScope: PoetryScope { didSet { defaults.set(poetryScope.rawValue, forKey: Key.poetryScope) } }
    @Published var automaticPoetryColor: Bool { didSet { defaults.set(automaticPoetryColor, forKey: Key.automaticPoetryColor) } }
    @Published var customPoetryColor: PoetryRGBA {
        didSet { defaults.set(try? JSONEncoder().encode(customPoetryColor), forKey: Key.poetryColor) }
    }
    @Published var customHoldDuration: Double { didSet { defaults.set(customHoldDuration, forKey: Key.customHoldDuration) } }
    @Published var customBlankDuration: Double { didSet { defaults.set(customBlankDuration, forKey: Key.customBlankDuration) } }
    @Published var backgroundMode: AmbientBackgroundMode { didSet { defaults.set(backgroundMode.rawValue, forKey: Key.backgroundMode) } }
    @Published var customBackgroundColor: PoetryRGBA {
        didSet { defaults.set(try? JSONEncoder().encode(customBackgroundColor), forKey: Key.backgroundColor) }
    }
    @Published var backgroundImageDim: Double { didSet { defaults.set(backgroundImageDim, forKey: Key.backgroundImageDim) } }
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var launchAtLoginError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppLanguage(rawValue: defaults.string(forKey: Key.language) ?? "") ?? .system
        appearance = AppearanceMode(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .system
        fontStyle = PoetryFontStyle(rawValue: defaults.string(forKey: Key.fontStyle) ?? "") ?? .song
        let savedSize = defaults.double(forKey: Key.fontSize)
        fontSize = savedSize == 0 ? 54 : min(96, max(28, savedSize))
        pace = PlaybackPace(rawValue: defaults.string(forKey: Key.pace) ?? "") ?? .standard
        showAuthor = defaults.object(forKey: Key.showAuthor) as? Bool ?? true
        showTitle = defaults.object(forKey: Key.showTitle) as? Bool ?? true
        showDynasty = defaults.object(forKey: Key.showDynasty) as? Bool ?? false
        avoidRecent = defaults.object(forKey: Key.avoidRecent) as? Bool ?? true
        layout = PoetryLayout(rawValue: defaults.string(forKey: Key.layout) ?? "") ?? .horizontal
        showMenuBar = defaults.object(forKey: Key.menuBar) as? Bool ?? true
        poetryScope = PoetryScope(rawValue: defaults.string(forKey: Key.poetryScope) ?? "") ?? .all
        automaticPoetryColor = defaults.object(forKey: Key.automaticPoetryColor) as? Bool ?? true
        if let data = defaults.data(forKey: Key.poetryColor), let value = try? JSONDecoder().decode(PoetryRGBA.self, from: data) {
            customPoetryColor = value
        } else {
            customPoetryColor = .warmInk
        }
        let savedHold = defaults.double(forKey: Key.customHoldDuration)
        customHoldDuration = savedHold == 0 ? 26 : min(120, max(8, savedHold))
        let savedBlank = defaults.double(forKey: Key.customBlankDuration)
        customBlankDuration = savedBlank == 0 ? 5 : min(15, max(1, savedBlank))
        backgroundMode = AmbientBackgroundMode(rawValue: defaults.string(forKey: Key.backgroundMode) ?? "") ?? .atmosphere
        if let data = defaults.data(forKey: Key.backgroundColor), let value = try? JSONDecoder().decode(PoetryRGBA.self, from: data) {
            customBackgroundColor = value
        } else {
            customBackgroundColor = .warmPaper
        }
        let savedDim = defaults.object(forKey: Key.backgroundImageDim) as? Double
        backgroundImageDim = min(0.75, max(0, savedDim ?? 0.26))
        applyApplicationAppearance(appearance)
    }

    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    func resolvedColorScheme(system: ColorScheme) -> ColorScheme {
        switch appearance {
        case .system: return system
        case .light: return .light
        case .dark: return .dark
        }
    }

    func selectAppearance(_ mode: AppearanceMode) {
        appearance = mode
        applyApplicationAppearance(mode)
    }

    private func applyApplicationAppearance(_ mode: AppearanceMode) {
        let selectedAppearance: NSAppearance?
        switch mode {
        case .system:
            selectedAppearance = nil
        case .light:
            selectedAppearance = NSAppearance(named: .aqua)
        case .dark:
            selectedAppearance = NSAppearance(named: .darkAqua)
        }
        DispatchQueue.main.async {
            NSApp.appearance = selectedAppearance
            for window in NSApp.windows {
                window.appearance = selectedAppearance
                window.contentView?.needsDisplay = true
            }
        }
    }

    var usesChinese: Bool {
        switch language {
        case .zhHans: return true
        case .english: return false
        case .system: return Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
        }
    }

    func text(_ chinese: String, _ english: String) -> String { usesChinese ? chinese : english }

    func setPoetryColor(_ color: Color) {
        guard let value = NSColor(color).usingColorSpace(.sRGB) else { return }
        customPoetryColor = PoetryRGBA(
            red: Double(value.redComponent),
            green: Double(value.greenComponent),
            blue: Double(value.blueComponent),
            alpha: Double(value.alphaComponent)
        )
    }

    func setBackgroundColor(_ color: Color) {
        guard let value = NSColor(color).usingColorSpace(.sRGB) else { return }
        customBackgroundColor = PoetryRGBA(
            red: Double(value.redComponent),
            green: Double(value.greenComponent),
            blue: Double(value.blueComponent),
            alpha: 1
        )
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchAtLoginError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchAtLoginError = error.localizedDescription
        }
    }
}
