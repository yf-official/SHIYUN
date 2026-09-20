import SwiftUI
import UniformTypeIdentifiers

private enum LibraryMode: String, CaseIterable, Identifiable {
    case favorites, complete, creations
    var id: String { rawValue }
}

struct FavoritesView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var favorites: FavoritesService
    @ObservedObject private var creative: CreativePoetryService
    @ObservedObject private var settings: AppSettings
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var mode: LibraryMode = .favorites
    @State private var searchText = ""
    @State private var selectedDynasty = ""
    @State private var selectedAuthor = ""
    @State private var cachedSourcePoems: [Poem] = []
    @State private var displayedPoems: [Poem] = []
    @State private var displayedCreations: [UserPoem] = []
    @State private var cachedDynasties: [String] = []
    @State private var cachedAuthors: [String] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var showingImporter = false
    @State private var showingImportGuide = false
    @State private var showingExporter = false
    @State private var exportDocument = PoetryCollectionDocument()
    @State private var exportContentType: UTType = .json
    @State private var exportFilename = "SHIYUN-My-Poetry"
    @State private var showingCreativeExporter = false
    @State private var creativeExportDocument = UserPoetryTextDocument()
    @State private var showingEditor = false
    @State private var editingPoem: UserPoem?
    @State private var poemPendingDeletion: UserPoem?
    @State private var notice: ImportExportNotice?

    init(model: AppModel) {
        self.model = model
        _favorites = ObservedObject(wrappedValue: model.favorites)
        _creative = ObservedObject(wrappedValue: model.creative)
        _settings = ObservedObject(wrappedValue: model.settings)
    }

    private var sourcePoems: [Poem] {
        cachedSourcePoems
    }

    private var dynasties: [String] { cachedDynasties }
    private var authors: [String] { cachedAuthors }

    var body: some View {
        VStack(spacing: 0) {
            libraryHeader
            if mode != .creations, !sourcePoems.isEmpty { filterBar }
            Divider().opacity(0.55)
            libraryContent
        }
        .navigationTitle(pageTitle)
        .environment(\.colorScheme, settings.resolvedColorScheme(system: systemColorScheme))
        .shiyunWindowAppearance(settings.appearance)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.shiyunCollection, .json, .commaSeparatedText, .plainText],
            allowsMultipleSelection: true
        ) { importCollections($0) }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: exportFilename
        ) { handleExportResult($0) }
        .fileExporter(
            isPresented: $showingCreativeExporter,
            document: creativeExportDocument,
            contentType: .plainText,
            defaultFilename: "SHIYUN-\(settings.text("我的创作", "My-Creations"))"
        ) { handleExportResult($0) }
        .sheet(isPresented: $showingImportGuide) { ImportFormatGuide(settings: settings) }
        .sheet(isPresented: $showingEditor, onDismiss: { editingPoem = nil }) {
            UserPoemEditor(service: creative, settings: settings, poem: editingPoem)
        }
        .alert(notice?.title ?? "", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button(settings.text("好", "OK")) { notice = nil }
        } message: {
            Text(notice?.message ?? "")
        }
        .alert(
            settings.text("删除这篇创作？", "Delete This Creation?"),
            isPresented: Binding(get: { poemPendingDeletion != nil }, set: { if !$0 { poemPendingDeletion = nil } })
        ) {
            Button(settings.text("删除", "Delete"), role: .destructive) { deletePendingPoem() }
            Button(settings.text("取消", "Cancel"), role: .cancel) { poemPendingDeletion = nil }
        } message: {
            Text(poemPendingDeletion?.title ?? "")
        }
        .task { rebuildSourceCache() }
        .onDisappear { searchTask?.cancel() }
        .onChange(of: searchText) { scheduleSearch() }
        .onChange(of: selectedDynasty) {
            rebuildAuthorCache()
            if !selectedAuthor.isEmpty && !cachedAuthors.contains(selectedAuthor) { selectedAuthor = "" }
            scheduleSearch(immediate: true)
        }
        .onChange(of: selectedAuthor) { scheduleSearch(immediate: true) }
        .onChange(of: favorites.ids) {
            if mode == .favorites { rebuildSourceCache() }
        }
        .onChange(of: creative.poems) {
            if mode == .creations { scheduleSearch(immediate: true) }
        }
        .onChange(of: mode) {
            searchText = ""
            selectedDynasty = ""
            selectedAuthor = ""
            rebuildSourceCache()
        }
    }

    private var pageTitle: String {
        switch mode {
        case .favorites: return settings.text("收藏", "Favorites")
        case .complete: return settings.text("诗词总库", "Poetry Library")
        case .creations: return settings.text("我的创作", "My Creations")
        }
    }

    @ViewBuilder private var libraryContent: some View {
        switch mode {
        case .favorites, .complete:
            if sourcePoems.isEmpty {
                ContentUnavailableView(
                    settings.text("还没有收藏", "No Favorites Yet"),
                    systemImage: "heart",
                    description: Text(settings.text("在诗境中点按心形收藏，或批量导入 JSON、CSV、TXT。", "Favorite a verse in SHIYUN, or batch import JSON, CSV, or TXT."))
                )
            } else if displayedPoems.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(displayedPoems) { poem in poemRow(poem) }
                    .listStyle(.inset)
            }
        case .creations:
            if let error = creative.lastError {
                ContentUnavailableView(settings.text("无法打开创作库", "Unable to Open Creation Library"), systemImage: "exclamationmark.triangle", description: Text(error))
            } else if creative.poems.isEmpty {
                ContentUnavailableView(
                    settings.text("写下第一首诗", "Write Your First Poem"),
                    systemImage: "square.and.pencil",
                    description: Text(settings.text("正文长度不限，内容只保存在这台 Mac。", "There is no length limit, and everything stays on this Mac."))
                )
            } else if displayedCreations.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(displayedCreations) { poem in creationRow(poem) }
                    .listStyle(.inset)
            }
        }
    }

    private func poemRow(_ poem: Poem) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(poem.text.joined(separator: "　"))
                    .font(SHIYUNTheme.poetryFont(style: settings.fontStyle, size: 20))
                    .lineSpacing(5)
                HStack(spacing: 7) {
                    Text(poem.dynasty)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(.secondary.opacity(0.1), in: Capsule())
                    Text(poem.author)
                    Text("《\(poem.title)》")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button { favorites.toggle(poem) } label: {
                Image(systemName: favorites.contains(poem) ? "heart.fill" : "heart")
                    .foregroundStyle(favorites.contains(poem) ? Color.red.opacity(0.8) : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(favorites.contains(poem) ? settings.text("取消收藏", "Remove Favorite") : settings.text("收藏", "Favorite"))
        }
        .padding(.vertical, 9)
    }

    private func creationRow(_ poem: UserPoem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(poem.title).font(.headline)
                Text(poem.body)
                    .font(SHIYUNTheme.poetryFont(style: settings.fontStyle, size: 17))
                    .lineLimit(3)
                    .foregroundStyle(.primary.opacity(0.86))
                Text(poem.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                editingPoem = poem
                showingEditor = true
            } label: { Image(systemName: "pencil") }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
        .contextMenu {
            Button(settings.text("编辑", "Edit")) { editingPoem = poem; showingEditor = true }
            Button(settings.text("删除", "Delete"), role: .destructive) { poemPendingDeletion = poem }
        }
    }

    private var libraryHeader: some View {
        VStack(spacing: 12) {
            Picker("", selection: $mode) {
                Text(settings.text("我的收藏", "Favorites")).tag(LibraryMode.favorites)
                Text(settings.text("诗词总库", "Full Library")).tag(LibraryMode.complete)
                Text(settings.text("我的创作", "My Creations")).tag(LibraryMode.creations)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            searchField

            HStack(spacing: 11) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(pageTitle).font(.title3.weight(.semibold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                headerActions
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 13)
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
            TextField(searchPrompt, text: $searchText).textFieldStyle(.plain)
            Button { searchText = "" } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .opacity(searchText.isEmpty ? 0 : 1)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(.primary.opacity(0.07)))
    }

    private var searchPrompt: String {
        mode == .creations
            ? settings.text("搜索标题或正文", "Search title or text")
            : settings.text("搜索诗句、作者或诗名", "Search verse, author, or title")
    }

    private var subtitle: String {
        switch mode {
        case .favorites: return settings.text("\(sourcePoems.count) 条收藏 · 仅保存在本机", "\(sourcePoems.count) favorites · Stored only on this Mac")
        case .complete: return settings.text("\(sourcePoems.count) 条诗词 · 支持全文搜索", "\(sourcePoems.count) verses · Full-text search")
        case .creations: return settings.text("\(creative.poems.count) 篇原创 · SQLite 本地数据库", "\(creative.poems.count) originals · Local SQLite database")
        }
    }

    @ViewBuilder private var headerActions: some View {
        switch mode {
        case .favorites:
            Text("JSON · CSV · TXT").font(.caption.monospaced()).foregroundStyle(.secondary)
            Button(settings.text("格式示例", "Examples")) { showingImportGuide = true }.buttonStyle(.link)
            Button { showingImporter = true } label: { Label(settings.text("批量导入", "Batch Import"), systemImage: "square.and.arrow.down") }
            exportMenu(poems: sourcePoems)
        case .complete:
            exportMenu(poems: sourcePoems)
        case .creations:
            Button {
                creativeExportDocument = UserPoetryTextDocument(poems: creative.poems)
                showingCreativeExporter = true
            } label: { Label(settings.text("导出 TXT", "Export TXT"), systemImage: "square.and.arrow.up") }
            .disabled(creative.poems.isEmpty)
            Button {
                editingPoem = nil
                showingEditor = true
            } label: { Label(settings.text("新建", "New"), systemImage: "square.and.pencil") }
            .buttonStyle(.borderedProminent)
        }
    }

    private func exportMenu(poems: [Poem]) -> some View {
        Menu {
            Button("JSON") { prepareCollectionExport(poems: poems, type: .json) }
            Button(settings.text("纯文本 TXT", "Plain Text TXT")) { prepareCollectionExport(poems: poems, type: .plainText) }
        } label: {
            Label(settings.text("导出", "Export"), systemImage: "square.and.arrow.up")
        }
        .disabled(poems.isEmpty)
    }

    private var filterBar: some View {
        HStack(spacing: 9) {
            filterMenu(title: selectedDynasty.isEmpty ? settings.text("全部朝代", "All Dynasties") : selectedDynasty, icon: "building.columns", allTitle: settings.text("全部朝代", "All Dynasties"), values: dynasties, selection: $selectedDynasty)
            filterMenu(title: selectedAuthor.isEmpty ? settings.text("全部作者", "All Authors") : selectedAuthor, icon: "person", allTitle: settings.text("全部作者", "All Authors"), values: authors, selection: $selectedAuthor)
            Spacer()
            Text(settings.text("显示 \(displayedPoems.count) 条", "Showing \(displayedPoems.count)"))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
    }

    private func filterMenu(title: String, icon: String, allTitle: String, values: [String], selection: Binding<String>) -> some View {
        Menu {
            Button(allTitle) { selection.wrappedValue = "" }
            Divider()
            ForEach(values, id: \.self) { value in Button(value) { selection.wrappedValue = value } }
        } label: {
            Label(title, systemImage: icon)
                .font(.callout).padding(.horizontal, 10).padding(.vertical, 6)
                .background(.primary.opacity(0.055), in: Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func prepareCollectionExport(poems: [Poem], type: UTType) {
        exportDocument = PoetryCollectionDocument(poems: poems)
        exportContentType = type
        exportFilename = "SHIYUN-\(mode == .complete ? settings.text("诗词总库", "Poetry-Library") : settings.text("我的诗选", "My-Poetry"))"
        showingExporter = true
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        if case .failure(let error) = result {
            notice = ImportExportNotice(title: settings.text("导出失败", "Export Failed"), message: error.localizedDescription)
        }
    }

    private func importCollections(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            var imported: [Poem] = []
            var failedFiles: [String] = []
            for url in urls {
                do { imported.append(contentsOf: try PoetryImportParser.parse(url: url)) }
                catch { failedFiles.append(url.lastPathComponent) }
            }
            guard !imported.isEmpty else { throw PoetryImportError.noPoems }
            let report = model.poetry.importPersonalDetailed(imported)
            favorites.add(report.collectionIDs)
            var lines = [settings.text("新增 \(report.addedIDs.count) 条。", "Added \(report.addedIDs.count).")]
            if report.duplicateCount > 0 { lines.append(settings.text("跳过重复 \(report.duplicateCount) 条；已有诗句已加入收藏。", "Skipped \(report.duplicateCount) duplicates; existing verses were added to favorites.")) }
            if report.invalidCount > 0 { lines.append(settings.text("跳过无效内容 \(report.invalidCount) 条。", "Skipped \(report.invalidCount) invalid entries.")) }
            if !failedFiles.isEmpty { lines.append(settings.text("未能读取：", "Could not read: ") + failedFiles.joined(separator: "、")) }
            notice = ImportExportNotice(title: settings.text("导入完成", "Import Complete"), message: lines.joined(separator: "\n"))
        } catch {
            notice = ImportExportNotice(title: settings.text("无法导入", "Import Failed"), message: error.localizedDescription)
        }
    }

    private func deletePendingPoem() {
        guard let poem = poemPendingDeletion else { return }
        do { try creative.delete(poem) }
        catch { notice = ImportExportNotice(title: settings.text("删除失败", "Delete Failed"), message: error.localizedDescription) }
        poemPendingDeletion = nil
    }

    private func rebuildSourceCache() {
        searchTask?.cancel()
        switch mode {
        case .favorites:
            cachedSourcePoems = favorites.ids.compactMap(model.poetry.poem(id:)).sorted {
                ($0.dynasty, $0.author, $0.title, $0.id) < ($1.dynasty, $1.author, $1.title, $1.id)
            }
        case .complete:
            cachedSourcePoems = model.poetry.sortedPoems
        case .creations:
            cachedSourcePoems = []
        }
        cachedDynasties = Array(Set(cachedSourcePoems.map(\.dynasty))).sorted()
        rebuildAuthorCache()
        scheduleSearch(immediate: true)
    }

    private func rebuildAuthorCache() {
        cachedAuthors = Array(Set(cachedSourcePoems.lazy
            .filter { selectedDynasty.isEmpty || $0.dynasty == selectedDynasty }
            .map(\.author))).sorted()
    }

    private func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()
        let requestedMode = mode
        let query = searchText
        let dynasty = selectedDynasty
        let author = selectedAuthor
        let favoriteIDs = requestedMode == .favorites ? favorites.ids : nil
        let creations = creative.poems

        searchTask = Task { @MainActor in
            if !immediate {
                try? await Task.sleep(for: .milliseconds(140))
            }
            guard !Task.isCancelled, mode == requestedMode, searchText == query else { return }
            if requestedMode == .creations {
                displayedCreations = creations.filter { poem in
                    query.isEmpty || poem.title.localizedStandardContains(query) || poem.body.localizedStandardContains(query)
                }
                displayedPoems = []
            } else {
                displayedPoems = model.poetry.search(
                    query: query,
                    dynasty: dynasty,
                    author: author,
                    allowedIDs: favoriteIDs
                )
                displayedCreations = []
            }
        }
    }
}

private struct ImportExportNotice {
    let title: String
    let message: String
}

private struct UserPoemEditor: View {
    @ObservedObject var service: CreativePoetryService
    @ObservedObject var settings: AppSettings
    let poem: UserPoem?
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var bodyText: String
    @State private var errorMessage: String?

    init(service: CreativePoetryService, settings: AppSettings, poem: UserPoem?) {
        self.service = service
        self.settings = settings
        self.poem = poem
        _title = State(initialValue: poem?.title ?? "")
        _bodyText = State(initialValue: poem?.body ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(poem == nil ? settings.text("新建创作", "New Creation") : settings.text("编辑创作", "Edit Creation"))
                    .font(.title2.weight(.semibold))
                Spacer()
                Text(settings.text("\(bodyText.count) 字", "\(bodyText.count) characters"))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            TextField(settings.text("标题", "Title"), text: $title)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $bodyText)
                .font(SHIYUNTheme.poetryFont(style: settings.fontStyle, size: 18))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.primary.opacity(0.08)))
            Text(settings.text("正文长度不限，自动保存在本机 SQLite 数据库中。", "There is no length limit. Your work is stored in a local SQLite database."))
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(settings.text("取消", "Cancel"), role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(settings.text("保存", "Save")) { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 620, height: 520)
        .alert(settings.text("无法保存", "Unable to Save"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button(settings.text("好", "OK")) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func save() {
        do {
            try service.save(id: poem?.id, title: title, body: bodyText)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ImportFormatGuide: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(settings.text("批量导入格式", "Batch Import Formats")).font(.title3.weight(.semibold))
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary) }
                        .buttonStyle(.plain).accessibilityLabel(settings.text("关闭", "Close"))
                }
                Text(settings.text(
                    "可以一次选择多个 JSON、CSV 或 TXT 文件。不需要填写标签；系统会自动查重。",
                    "Select multiple JSON, CSV, or TXT files at once. Tags are not required, and duplicates are detected automatically."
                ))
                .font(.callout).foregroundStyle(.secondary)

                example(title: "TXT", note: settings.text("每首之间空一行；最后一行是作者、诗名、朝代。", "Separate poems with a blank line; the last line is author, title, and dynasty."), content: """
                明月松间照
                清泉石上流
                王维 | 山居秋暝 | 唐
                """)
                example(title: "CSV", note: settings.text("只要求 text 列，两句用 / 分隔。", "Only text is required; separate two lines with /."), content: """
                text,author,title,dynasty
                "明月松间照/清泉石上流",王维,山居秋暝,唐
                """)
                example(title: "JSON", note: settings.text("id、标签等字段均可省略。", "ID, tags, and other fields may be omitted."), content: """
                [{
                  "text": ["明月松间照", "清泉石上流"],
                  "author": "王维",
                  "title": "山居秋暝",
                  "dynasty": "唐"
                }]
                """)
            }
            .padding(22)
        }
        .frame(width: 560, height: 470)
    }

    private func example(title: String, note: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            Text(verbatim: content)
                .font(.system(size: 12, design: .monospaced)).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }
}
