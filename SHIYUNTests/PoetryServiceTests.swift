import XCTest
@testable import SHIYUN

final class PoetryServiceTests: XCTestCase {
    func testCachePolicyKeepsOnlyBoundedAppCache() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SHIYUNCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        for index in 0..<4 {
            let url = directory.appendingPathComponent("\(index).cache")
            try Data(repeating: UInt8(index), count: 1_024).write(to: url)
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: TimeInterval(index))],
                ofItemAtPath: url.path
            )
        }

        AppCachePolicy.enforce(directory: directory, limitBytes: 2_048)

        let remaining = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        )
        let total = try remaining.reduce(Int64(0)) {
            $0 + Int64(try $1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        }
        XCTAssertLessThanOrEqual(total, 2_048)
        XCTAssertEqual(Set(remaining.map(\.lastPathComponent)), ["2.cache", "3.cache"])
    }

    func testBundledDatasetIsLargeAndValid() throws {
        let poems = try PoetryService.load(from: .main)
        XCTAssertGreaterThanOrEqual(poems.count, 3_000)
        XCTAssertEqual(Set(poems.map(\.id)).count, poems.count)
        XCTAssertTrue(poems.allSatisfy { !$0.text.isEmpty && !$0.author.isEmpty && !$0.title.isEmpty })
    }

    func testEveryReferenceSelectionIsBundled() throws {
        let joined = try PoetryService.load(from: .main).map { $0.text.joined() }
        let selections = [
            "春风若有怜花意可否许我再少年", "人生若只如初见何事秋风悲画扇", "最是人间留不住朱颜辞镜花辞树",
            "欲买桂花同载酒终不似，少年游", "此情可待成追忆只是当时已惘然", "相逢已是上上签何用相思煮余年",
            "相见时难别亦难东风无力百花残", "自古逢秋悲寂寥我言秋日胜春朝", "劝君莫惜金缕衣劝君惜取少年时",
            "山有木兮木有枝心悦君兮君不知", "锦瑟无端五十弦一弦一柱思华年", "天长地久有时尽此恨绵绵无绝期",
            "花开堪折直须折莫待无花空折枝", "在天愿作比翼鸟在地愿为连理枝", "他朝若是同淋雪此生也算共白头",
            "我本将心照明月奈何明月照沟渠", "人道洛阳花似锦偏我来时不逢春", "年年岁岁花相似岁岁年年人不同",
            "侯门一入深如海从此萧郎是路人", "从此烟尘各悄然春山如黛草如烟", "辞别再无相见日终是一人度春秋",
            "伤心桥下春波绿曾是惊鸿照影来", "所得终是水中月枯木能逢几回春", "我与春风皆过客你携秋水揽星河"
        ]
        for selection in selections {
            XCTAssertTrue(joined.contains(selection), "Missing reference selection: \(selection)")
        }
    }

    func testIndexedLibrarySearchMatchesVerseAuthorAndTitle() {
        let service = PoetryService(bundle: .main)
        XCTAssertTrue(service.search(query: "明月照沟渠").contains { $0.text.joined().contains("明月照沟渠") })
        XCTAssertTrue(service.search(query: "李商隐").allSatisfy { $0.author == "李商隐" })
        XCTAssertTrue(service.search(query: "锦瑟").contains { $0.title == "锦瑟" })
        XCTAssertEqual(service.search(query: "明月", dynasty: "唐").filter { $0.dynasty != "唐" }.count, 0)
    }

    func testShuffleBagAvoidsImmediateRepeats() {
        let service = PoetryService(bundle: .main)
        let sample = (0..<100).map { _ in service.next().id }
        XCTAssertEqual(Set(sample).count, sample.count)
    }

    func testPlaybackCanBeLimitedToPersonalSelection() {
        let service = PoetryService(bundle: .main)
        let selected = Set(service.poems.prefix(5).map(\.id))
        let sample = (0..<20).map { _ in service.next(allowedIDs: selected).id }
        XCTAssertTrue(sample.allSatisfy(selected.contains))
    }

    func testImportedPoemPersistsInPersonalLibrary() {
        let suiteName = "SHIYUNTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let imported = Poem(
            id: "personal_test",
            text: ["测试云影收秋色", "测试松声入晚窗"],
            author: "测试作者",
            title: "测试诗选",
            dynasty: "今",
            tags: ["花", "月"],
            mood: "calm",
            length: "short"
        )

        let first = PoetryService(bundle: .main, defaults: defaults)
        XCTAssertEqual(first.importPersonal([imported]), ["personal_test"])
        let reloaded = PoetryService(bundle: .main, defaults: defaults)
        XCTAssertEqual(reloaded.poem(id: "personal_test"), imported)
    }

    func testFiftyThousandSelectionsKeepAllBuffersBounded() {
        let service = PoetryService(bundle: .main)
        let initialCount = service.poems.count

        for _ in 0..<50_000 {
            autoreleasepool { _ = service.next() }
        }

        let state = service.diagnostics
        XCTAssertEqual(state.poemCount, initialCount)
        XCTAssertLessThanOrEqual(state.shuffleBagCount, initialCount)
        XCTAssertLessThanOrEqual(state.recentCount, 60)
    }

    func testImportDeduplicatesVerseDespitePunctuationAndSpacing() {
        let suiteName = "SHIYUNTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let service = PoetryService(bundle: .main, defaults: defaults)
        let first = Poem(
            id: "personal_one",
            text: ["测试清风入夜来，", "一窗明月照书台。"],
            author: "甲", title: "其一", dynasty: "今", tags: [], mood: "calm", length: "short"
        )
        let duplicate = Poem(
            id: "personal_two",
            text: ["测试清风入夜来", "一窗明月照书台"],
            author: "乙", title: "其二", dynasty: "今", tags: [], mood: "calm", length: "short"
        )

        let report = service.importPersonalDetailed([first, duplicate])

        XCTAssertEqual(report.addedIDs, ["personal_one"])
        XCTAssertEqual(report.duplicateCount, 1)
        XCTAssertEqual(report.invalidCount, 0)
    }

    func testCSVAndStructuredTextImport() throws {
        let csv = """
        text,author,title,dynasty,tags
        "明月松间照/清泉石上流",王维,山居秋暝,唐,"山水;月"
        """
        let csvPoems = try PoetryImportParser.parseCSV(csv)
        XCTAssertEqual(csvPoems.count, 1)
        XCTAssertEqual(csvPoems[0].text, ["明月松间照", "清泉石上流"])
        XCTAssertEqual(csvPoems[0].tags, ["山水", "月"])

        let text = """
        疏影横斜水清浅
        暗香浮动月黄昏
        林逋 | 山园小梅 | 宋 | 花;月

        诗句：竹外桃花三两枝/春江水暖鸭先知
        作者：苏轼
        标题：惠崇春江晚景
        朝代：宋
        标签：春;江
        """
        let textPoems = PoetryImportParser.parseText(text)
        XCTAssertEqual(textPoems.count, 2)
        XCTAssertEqual(textPoems[0].author, "林逋")
        XCTAssertEqual(textPoems[1].title, "惠崇春江晚景")
    }

    func testFlexibleJSONDoesNotRequireTagsOrInternalFields() throws {
        let json = """
        [{
          "text": ["明月松间照", "清泉石上流"],
          "author": "王维",
          "title": "山居秋暝",
          "dynasty": "唐"
        }]
        """
        let poems = try PoetryImportParser.parseJSON(Data(json.utf8))
        XCTAssertEqual(poems.count, 1)
        XCTAssertEqual(poems[0].tags, ["自选"])
    }

    func testPlainTextExportMatchesRequestedSingleLineAndCanBeImported() {
        let poem = Poem(
            id: "sample", text: ["明月松间照", "清泉石上流"], author: "王维",
            title: "山居秋暝", dynasty: "唐", tags: [], mood: "calm", length: "short"
        )
        let line = PoetryCollectionDocument.plainTextLine(poem)
        XCTAssertEqual(line, "明月松间照，清泉石上流。--山居秋暝  唐·王维")
        let imported = PoetryImportParser.parseText(line)
        XCTAssertEqual(imported.first?.text, poem.text)
        XCTAssertEqual(imported.first?.author, poem.author)
        XCTAssertEqual(imported.first?.title, poem.title)
        XCTAssertEqual(imported.first?.dynasty, poem.dynasty)
    }

    @MainActor
    func testCreativePoetryDatabasePersistsUnlimitedBody() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SHIYUNTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let longBody = String(repeating: "云水之间，自有清音。", count: 3_000)

        do {
            let service = CreativePoetryService(baseDirectory: directory)
            try service.save(title: "长歌", body: longBody)
            XCTAssertEqual(service.poems.first?.body.count, longBody.count)
        }

        let reloaded = CreativePoetryService(baseDirectory: directory)
        XCTAssertEqual(reloaded.poems.first?.title, "长歌")
        XCTAssertEqual(reloaded.poems.first?.body, longBody)
    }
}
