import AppKit
import Combine
import Foundation
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class BackgroundService: ObservableObject {
    @Published private(set) var image: NSImage?
    @Published private(set) var fileName: String?

    private let imageURL: URL
    private let nameKey = "customBackgroundFileName"
    private let defaults: UserDefaults
    private let maximumImageBytes = 6 * 1024 * 1024

    init(defaults: UserDefaults = .standard, baseDirectory: URL? = nil) {
        self.defaults = defaults
        let root = baseDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent("SHIYUN", isDirectory: true)
        imageURL = directory.appendingPathComponent("custom-background.jpg", isDirectory: false)
        image = NSImage(contentsOf: imageURL)
        fileName = image == nil ? nil : defaults.string(forKey: nameKey)
    }

    func importImage(from sourceURL: URL) throws {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 3840
              ] as CFDictionary) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var jpeg: Data?
        for quality in [0.82, 0.72, 0.62, 0.52] {
            let candidate = Self.jpegData(from: cgImage, quality: quality)
            jpeg = candidate
            if let candidate, candidate.count <= maximumImageBytes { break }
        }
        guard let jpeg, jpeg.count <= maximumImageBytes else {
            throw CocoaError(.fileWriteUnknown)
        }

        try FileManager.default.createDirectory(at: imageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try jpeg.write(to: imageURL, options: .atomic)
        image = NSImage(data: jpeg)
        fileName = sourceURL.lastPathComponent
        defaults.set(fileName, forKey: nameKey)
    }

    func removeImage() throws {
        if FileManager.default.fileExists(atPath: imageURL.path) {
            try FileManager.default.removeItem(at: imageURL)
        }
        image = nil
        fileName = nil
        defaults.removeObject(forKey: nameKey)
    }

    private static func jpegData(from image: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
