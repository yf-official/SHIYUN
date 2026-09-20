import AppKit
import SwiftUI

enum SHIYUNTheme {
    static let darkInk = Color(red: 0.035, green: 0.045, blue: 0.06)
    static let lightPaper = Color(red: 0.955, green: 0.945, blue: 0.91)
    static let warmLight = Color(red: 0.86, green: 0.82, blue: 0.72)
    private static let poetryFontNames: [PoetryFontStyle: String] = [
        .song: availableFont(["Songti SC", "STSongti-SC-Regular"]),
        .kai: availableFont(["Kaiti SC", "STKaiti-SC-Regular"]),
        .modern: availableFont(["PingFang SC", ".AppleSystemUIFont"]),
        .hei: availableFont(["Heiti SC", "STHeitiSC-Light"]),
        .fangSong: availableFont(["STFangsong", "FangSong"]),
        .yuan: availableFont(["Yuanti SC", "STYuanti-SC-Regular"]),
        .liSong: availableFont(["LiSong Pro", "STSongti-SC-Light"]),
        .weiBei: availableFont(["Weibei SC", "STKaiti-SC-Regular"]),
        .lanTing: availableFont(["Lantinghei SC", "PingFang SC"])
    ]

    static func poetryFont(style: PoetryFontStyle, size: Double) -> Font {
        .custom(poetryFontNames[style] ?? "Songti SC", size: size, relativeTo: .title)
    }

    private static func availableFont(_ candidates: [String]) -> String {
        candidates.first { NSFont(name: $0, size: 16) != nil } ?? "Songti SC"
    }

    static func resolvedBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkInk : lightPaper
    }
}

private struct WindowAppearanceBridge: NSViewRepresentable {
    let mode: AppearanceMode

    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ nsView: NSView, context: Context) {
        let appearance: NSAppearance?
        switch mode {
        case .system: appearance = nil
        case .light: appearance = NSAppearance(named: .aqua)
        case .dark: appearance = NSAppearance(named: .darkAqua)
        }

        // Updating a window's appearance invalidates the SwiftUI view tree. Do
        // not assign the same value on every update, otherwise SwiftUI and
        // AppKit continuously invalidate each other and keep the CPU awake.
        guard let window = nsView.window else { return }
        guard window.appearance?.name != appearance?.name else { return }
        window.appearance = appearance
    }
}

extension View {
    func shiyunWindowAppearance(_ mode: AppearanceMode) -> some View {
        background(WindowAppearanceBridge(mode: mode).frame(width: 0, height: 0))
    }
}
