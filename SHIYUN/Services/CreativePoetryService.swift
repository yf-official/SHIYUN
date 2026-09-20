import Combine
import Foundation
import SQLite3

enum CreativePoetryDatabaseError: LocalizedError {
    case open(String)
    case operation(String)

    var errorDescription: String? {
        switch self {
        case .open(let message): return "无法打开本地创作数据库：\(message)"
        case .operation(let message): return "本地创作数据库操作失败：\(message)"
        }
    }
}

@MainActor
final class CreativePoetryService: ObservableObject {
    @Published private(set) var poems: [UserPoem] = []
    @Published private(set) var lastError: String?

    private var database: OpaquePointer?
    private let databaseURL: URL
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(baseDirectory: URL? = nil) {
        let root = baseDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent("SHIYUN", isDirectory: true)
        databaseURL = directory.appendingPathComponent("user-poetry.sqlite3", isDirectory: false)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try openDatabase()
            try createSchema()
            try reload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    deinit {
        if let database { sqlite3_close(database) }
    }

    func save(id: String? = nil, title: String, body: String) throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, !cleanBody.isEmpty else {
            throw CreativePoetryDatabaseError.operation("标题和正文不能为空。")
        }

        let now = Date().timeIntervalSince1970
        if let id, poems.contains(where: { $0.id == id }) {
            let sql = "UPDATE user_poems SET title = ?, body = ?, updated_at = ? WHERE id = ?;"
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }
            bind(cleanTitle, to: 1, in: statement)
            bind(cleanBody, to: 2, in: statement)
            sqlite3_bind_double(statement, 3, now)
            bind(id, to: 4, in: statement)
            try step(statement)
        } else {
            let sql = "INSERT INTO user_poems (id, title, body, created_at, updated_at) VALUES (?, ?, ?, ?, ?);"
            let statement = try prepare(sql)
            defer { sqlite3_finalize(statement) }
            bind(id ?? UUID().uuidString.lowercased(), to: 1, in: statement)
            bind(cleanTitle, to: 2, in: statement)
            bind(cleanBody, to: 3, in: statement)
            sqlite3_bind_double(statement, 4, now)
            sqlite3_bind_double(statement, 5, now)
            try step(statement)
        }
        try reload()
    }

    func delete(_ poem: UserPoem) throws {
        let statement = try prepare("DELETE FROM user_poems WHERE id = ?;")
        defer { sqlite3_finalize(statement) }
        bind(poem.id, to: 1, in: statement)
        try step(statement)
        try reload()
    }

    private func openDatabase() throws {
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
            throw CreativePoetryDatabaseError.open(errorMessage)
        }
        sqlite3_busy_timeout(database, 2_000)
    }

    private func createSchema() throws {
        let sql = """
        CREATE TABLE IF NOT EXISTS user_poems (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS user_poems_updated_at ON user_poems(updated_at DESC);
        """
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw CreativePoetryDatabaseError.operation(errorMessage)
        }
    }

    private func reload() throws {
        let statement = try prepare("SELECT id, title, body, created_at, updated_at FROM user_poems ORDER BY updated_at DESC;")
        defer { sqlite3_finalize(statement) }
        var loaded: [UserPoem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            loaded.append(UserPoem(
                id: string(at: 0, in: statement),
                title: string(at: 1, in: statement),
                body: string(at: 2, in: statement),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))
            ))
        }
        poems = loaded
        lastError = nil
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw CreativePoetryDatabaseError.operation(errorMessage)
        }
        return statement
    }

    private func step(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw CreativePoetryDatabaseError.operation(errorMessage)
        }
    }

    private func bind(_ value: String, to index: Int32, in statement: OpaquePointer) {
        sqlite3_bind_text(statement, index, value, -1, transient)
    }

    private func string(at index: Int32, in statement: OpaquePointer) -> String {
        guard let value = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: value)
    }

    private var errorMessage: String {
        database.flatMap(sqlite3_errmsg).map(String.init(cString:)) ?? "Unknown SQLite error"
    }
}
