import AppKit
import SwiftUI

@main
struct SHIYUNApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            AmbientView(model: model)
                .frame(minWidth: 720, minHeight: 480)
        }
        .defaultSize(width: 1120, height: 720)
        .windowStyle(.hiddenTitleBar)
        .commands {
            SHIYUNCommands(model: model)
        }

        Window(model.settings.text("收藏", "Favorites"), id: "favorites") {
            FavoritesView(model: model)
                .frame(minWidth: 620, minHeight: 440)
        }
        .defaultSize(width: 760, height: 560)

        Settings {
            SettingsView(model: model)
        }

        MenuBarExtra("SHIYUN", systemImage: "text.quote", isInserted: Binding(
            get: { model.settings.showMenuBar },
            set: { newValue in
                // SwiftUI may re-apply the menu-bar configuration while it is
                // rebuilding scenes. Avoid publishing an identical value,
                // which otherwise creates a self-sustaining update loop.
                guard model.settings.showMenuBar != newValue else { return }
                model.settings.showMenuBar = newValue
            }
        )) {
            MenuBarContent(model: model)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct SHIYUNCommands: Commands {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(model.settings.text("下一句", "Next Verse")) { model.scheduler.next() }
            Button(model.settings.text("收藏当前诗句", "Favorite Current Verse")) {
                model.favorites.toggle(model.scheduler.current)
            }
            .keyboardShortcut("f", modifiers: [.command])
            Divider()
            Button(model.settings.text("收藏", "Favorites")) { openWindow(id: "favorites") }
                .keyboardShortcut("l", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .appSettings) {
            Button(model.settings.text("设置…", "Settings…")) { openSettings() }
                .keyboardShortcut(",", modifiers: .command)
        }
    }
}

struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(model.settings.text("进入诗境", "Enter SHIYUN")) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
        }
        Button(model.settings.text("下一句", "Next Verse")) { model.scheduler.next() }
        Button(model.settings.text("收藏当前诗句", "Favorite Current Verse")) {
            model.favorites.toggle(model.scheduler.current)
        }
        Divider()
        Button(model.settings.text("收藏", "Favorites")) { openWindow(id: "favorites") }
        Button(model.settings.text("设置…", "Settings…")) { openSettings() }
        Divider()
        Button(model.settings.text("退出", "Quit")) { NSApp.terminate(nil) }
    }
}
