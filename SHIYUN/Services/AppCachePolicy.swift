import Foundation

enum AppCachePolicy {
    static let maximumDiskBytes: Int64 = 8 * 1024 * 1024

    /// Keeps only SHIYUN's disposable cache bounded. User poetry, favorites,
    /// the SQLite database and the selected background are not cache data.
    static func enforce(
        directory: URL? = nil,
        limitBytes: Int64 = maximumDiskBytes,
        fileManager: FileManager = .default
    ) {
        URLCache.shared.memoryCapacity = 512 * 1024
        URLCache.shared.diskCapacity = 0
        URLCache.shared.removeAllCachedResponses()

        let cacheDirectory = directory ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.shiyun.app", isDirectory: true)
        guard fileManager.fileExists(atPath: cacheDirectory.path),
              let enumerator = fileManager.enumerator(
                at: cacheDirectory,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else { return }

        var files: [(url: URL, bytes: Int64, date: Date)] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isRegularFile == true else { continue }
            files.append((url, Int64(values.fileSize ?? 0), values.contentModificationDate ?? .distantPast))
        }

        var totalBytes = files.reduce(Int64(0)) { $0 + $1.bytes }
        guard totalBytes > limitBytes else { return }
        for file in files.sorted(by: { $0.date < $1.date }) where totalBytes > limitBytes {
            do {
                try fileManager.removeItem(at: file.url)
                totalBytes -= file.bytes
            } catch {
                NSLog("SHIYUN: unable to trim cache item %@: %@", file.url.lastPathComponent, error.localizedDescription)
            }
        }
    }
}
