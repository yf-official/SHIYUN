import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: AppSettings
    @Environment(\.colorScheme) private var systemColorScheme

    init(model: AppModel) {
        self.model = model
        _settings = ObservedObject(wrappedValue: model.settings)
    }

    var body: some View {
        TabView {
            GeneralSettingsView(settings: model.settings)
                .tabItem { Label(model.settings.text("通用", "General"), systemImage: "switch.2") }
            DisplaySettingsView(settings: model.settings)
                .tabItem { Label(model.settings.text("显示", "Display"), systemImage: "rectangle.on.rectangle") }
            PoetrySettingsView(model: model)
                .tabItem { Label(model.settings.text("诗词", "Poetry"), systemImage: "text.quote") }
            FavoritesView(model: model)
                .tabItem { Label(model.settings.text("诗库", "Library"), systemImage: "books.vertical") }
            AppearanceSettingsView(model: model)
                .tabItem { Label(model.settings.text("外观", "Appearance"), systemImage: "circle.lefthalf.filled") }
            AboutView(settings: model.settings)
                .tabItem { Label(model.settings.text("关于", "About"), systemImage: "info.circle") }
        }
        .frame(width: 720, height: 560)
        .padding(.top, 8)
        .environment(\.colorScheme, settings.resolvedColorScheme(system: systemColorScheme))
        .shiyunWindowAppearance(settings.appearance)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Picker(settings.text("界面语言", "Interface Language"), selection: $settings.language) {
                Text(settings.text("跟随系统", "System Default")).tag(AppLanguage.system)
                Text("简体中文").tag(AppLanguage.zhHans)
                Text("English").tag(AppLanguage.english)
            }
            Toggle(settings.text("在菜单栏显示 SHIYUN", "Show SHIYUN in Menu Bar"), isOn: $settings.showMenuBar)
            Toggle(settings.text("登录时打开", "Open at Login"), isOn: Binding(
                get: { settings.launchAtLogin },
                set: { settings.setLaunchAtLogin($0) }
            ))
            if let error = settings.launchAtLoginError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .padding(18)
    }
}

private struct DisplaySettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Picker(settings.text("排版", "Layout"), selection: $settings.layout) {
                Text(settings.text("横排", "Horizontal")).tag(PoetryLayout.horizontal)
                Text(settings.text("竖排", "Vertical")).tag(PoetryLayout.vertical)
            }
            Picker(settings.text("字体", "Typeface"), selection: $settings.fontStyle) {
                fontOption(settings.text("宋体", "Song Serif"), .song)
                fontOption(settings.text("楷体", "Kai Script"), .kai)
                fontOption(settings.text("苹方", "PingFang"), .modern)
                fontOption(settings.text("黑体", "Hei Sans"), .hei)
                fontOption(settings.text("仿宋", "FangSong"), .fangSong)
                fontOption(settings.text("圆体", "Rounded"), .yuan)
                fontOption(settings.text("丽宋", "LiSong"), .liSong)
                fontOption(settings.text("魏碑", "WeiBei"), .weiBei)
                fontOption(settings.text("兰亭黑", "Lanting Sans"), .lanTing)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(settings.text("字号", "Type Size"))
                    Spacer()
                    Text("\(Int(settings.fontSize)) pt").foregroundStyle(.secondary)
                }
                Slider(value: $settings.fontSize, in: 28...96, step: 2)
                    .accessibilityLabel(settings.text("诗句字号", "Poetry Type Size"))
            }
            Toggle(settings.text("自动适配诗句颜色", "Automatic Poetry Color"), isOn: $settings.automaticPoetryColor)
            ColorPicker(
                settings.text("自定义诗句颜色", "Custom Poetry Color"),
                selection: Binding(
                    get: { settings.customPoetryColor.color },
                    set: { settings.setPoetryColor($0) }
                ),
                supportsOpacity: true
            )
            .disabled(settings.automaticPoetryColor)
        }
        .formStyle(.grouped)
        .padding(18)
    }

    private func fontOption(_ title: String, _ style: PoetryFontStyle) -> some View {
        Text(title)
            .font(SHIYUNTheme.poetryFont(style: style, size: 14))
            .tag(style)
    }
}

private struct PoetrySettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: AppSettings
    @ObservedObject private var favorites: FavoritesService

    init(model: AppModel) {
        self.model = model
        _settings = ObservedObject(wrappedValue: model.settings)
        _favorites = ObservedObject(wrappedValue: model.favorites)
    }

    var body: some View {
        Form {
            Section(settings.text("播放", "Playback")) {
                Picker(settings.text("播放范围", "Playback Collection"), selection: $settings.poetryScope) {
                    Text(settings.text("全部诗词", "All Poetry")).tag(PoetryScope.all)
                    Text(settings.text("只播放我的收藏（\(favorites.ids.count)）", "My Favorites Only (\(favorites.ids.count))"))
                        .tag(PoetryScope.favorites)
                }
                if settings.poetryScope == .favorites && favorites.ids.isEmpty {
                    Text(settings.text("收藏为空时会继续播放完整诗库。", "The complete library plays until you add a favorite."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Picker(settings.text("节奏", "Pace"), selection: $settings.pace) {
                    Text(settings.text("舒缓", "Relaxed")).tag(PlaybackPace.relaxed)
                    Text(settings.text("标准", "Standard")).tag(PlaybackPace.standard)
                    Text(settings.text("稍快", "Brisk")).tag(PlaybackPace.brisk)
                    Text(settings.text("自定义", "Custom")).tag(PlaybackPace.custom)
                }
                if settings.pace == .custom {
                    durationSlider(
                        title: settings.text("诗句停留", "Verse Hold"),
                        value: $settings.customHoldDuration,
                        range: 8...120
                    )
                    durationSlider(
                        title: settings.text("留白时间", "Blank Interval"),
                        value: $settings.customBlankDuration,
                        range: 1...15
                    )
                    Text(settings.text("实际时间会有约 ±10% 的自然变化。", "Timing varies naturally by about ±10%."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle(settings.text("避免近期重复", "Avoid Recent Verses"), isOn: $settings.avoidRecent)
            }
            Section(settings.text("署名信息", "Attribution")) {
                Toggle(settings.text("显示作者", "Show Author"), isOn: $settings.showAuthor)
                Toggle(settings.text("显示诗名", "Show Title"), isOn: $settings.showTitle)
                Toggle(settings.text("显示朝代", "Show Dynasty"), isOn: $settings.showDynasty)
            }
        }
        .formStyle(.grouped)
        .padding(18)
    }

    private func durationSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue)) s").foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: value, in: range, step: 1)
                .accessibilityLabel(title)
        }
    }
}

private struct AppearanceSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var background: BackgroundService
    @State private var showingImageImporter = false
    @State private var errorMessage: String?

    init(model: AppModel) {
        self.model = model
        _settings = ObservedObject(wrappedValue: model.settings)
        _background = ObservedObject(wrappedValue: model.background)
    }

    var body: some View {
        Form {
            Section(settings.text("界面", "Interface")) {
                Picker(settings.text("外观", "Appearance"), selection: Binding(
                    get: { settings.appearance },
                    set: { settings.selectAppearance($0) }
                )) {
                    Text(settings.text("跟随系统", "System Default")).tag(AppearanceMode.system)
                    Text(settings.text("浅色", "Light")).tag(AppearanceMode.light)
                    Text(settings.text("深色", "Dark")).tag(AppearanceMode.dark)
                }
            }

            Section(settings.text("诗境背景", "Poetry Background")) {
                Picker(settings.text("背景", "Background"), selection: $settings.backgroundMode) {
                    Text(settings.text("默认氛围", "Atmosphere")).tag(AmbientBackgroundMode.atmosphere)
                    Text(settings.text("纯色", "Solid Color")).tag(AmbientBackgroundMode.color)
                    Text(settings.text("我的图片", "My Image")).tag(AmbientBackgroundMode.image)
                }
                .pickerStyle(.segmented)

                backgroundEditor
            }

            Text(settings.text(
                "图片仅保存在这台 Mac，并会自动缩放到适合显示的尺寸，避免运行时持续占用更多内存。",
                "The image stays on this Mac and is resized for display so memory usage remains bounded."
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding(18)
        .fileImporter(isPresented: $showingImageImporter, allowedContentTypes: [.image]) { result in
            do {
                try background.importImage(from: result.get())
                settings.backgroundMode = .image
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .alert(settings.text("无法使用这张图片", "Unable to Use Image"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(settings.text("好", "OK")) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder private var backgroundEditor: some View {
        switch settings.backgroundMode {
        case .atmosphere:
            HStack(spacing: 12) {
                backgroundPreview
                Text(settings.text("随诗句缓慢变化的纸色光影", "Quiet paper tones that shift with each verse"))
                    .foregroundStyle(.secondary)
            }
        case .color:
            HStack(spacing: 12) {
                backgroundPreview
                ColorPicker(
                    settings.text("背景颜色", "Background Color"),
                    selection: Binding(
                        get: { settings.customBackgroundColor.color },
                        set: { settings.setBackgroundColor($0) }
                    ),
                    supportsOpacity: false
                )
            }
        case .image:
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    backgroundPreview
                    VStack(alignment: .leading, spacing: 7) {
                        Text(background.fileName ?? settings.text("尚未选择图片", "No image selected"))
                            .lineLimit(1)
                            .foregroundStyle(background.image == nil ? .secondary : .primary)
                        HStack {
                            Button(background.image == nil ? settings.text("选择图片…", "Choose Image…") : settings.text("更换…", "Replace…")) {
                                showingImageImporter = true
                            }
                            if background.image != nil {
                                Button(settings.text("移除", "Remove"), role: .destructive) {
                                    do {
                                        try background.removeImage()
                                        settings.backgroundMode = .atmosphere
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            }
                        }
                    }
                }
                if background.image != nil {
                    HStack {
                        Text(settings.text("暗化图片", "Image Shade"))
                        Slider(value: $settings.backgroundImageDim, in: 0...0.75, step: 0.05)
                        Text("\(Int(settings.backgroundImageDim * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 38, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var backgroundPreview: some View {
        ZStack {
            switch settings.backgroundMode {
            case .atmosphere:
                LinearGradient(colors: [Color(red: 0.96, green: 0.95, blue: 0.91), Color(red: 0.85, green: 0.88, blue: 0.89)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .color:
                settings.customBackgroundColor.color
            case .image:
                if let image = background.image {
                    Image(nsImage: image).resizable().scaledToFill()
                    Color.black.opacity(settings.backgroundImageDim)
                } else {
                    Color.secondary.opacity(0.12)
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 116, height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(.primary.opacity(0.09)))
    }
}
