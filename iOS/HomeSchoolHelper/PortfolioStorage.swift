import Foundation
#if canImport(UIKit)
import UIKit
#endif

public final class PortfolioStorage {
    public static let shared = PortfolioStorage()

    public let directoryURL: URL

    public init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            #if DEBUG
            if let rawID = ProcessInfo.processInfo.environment["HSH_UI_TEST_ID"],
               let id = UUID(uuidString: rawID) {
                self.directoryURL = URL.applicationSupportDirectory
                    .appendingPathComponent("HomeSchoolHelperUITests", isDirectory: true)
                    .appendingPathComponent(id.uuidString, isDirectory: true)
                    .appendingPathComponent("Portfolios", isDirectory: true)
            } else {
                self.directoryURL = URL.applicationSupportDirectory
                    .appendingPathComponent("HomeSchoolHelper", isDirectory: true)
                    .appendingPathComponent("Portfolios", isDirectory: true)
            }
            #else
            self.directoryURL = URL.applicationSupportDirectory
                .appendingPathComponent("HomeSchoolHelper", isDirectory: true)
                .appendingPathComponent("Portfolios", isDirectory: true)
            #endif
        }
        try? FileManager.default.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
    }

    #if canImport(UIKit)
    /// Saves JPEG data to disk and returns the relative fileName (e.g. "<uuid>.jpg")
    @discardableResult
    public func saveImage(_ image: UIImage, compressionQuality: CGFloat = 0.85) throws -> String {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw NSError(
                domain: "PortfolioStorage",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode image as JPEG."]
            )
        }
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = directoryURL.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileName
    }

    /// Loads image by fileName
    public func loadImage(fileName: String) -> UIImage? {
        let fileURL = directoryURL.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    #endif

    /// Saves raw image data directly (e.g., from PhotosPicker or camera Data)
    @discardableResult
    public func saveData(_ data: Data, fileExtension: String = "jpg") throws -> String {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileName = "\(UUID().uuidString).\(fileExtension)"
        let fileURL = directoryURL.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileName
    }

    /// Loads raw image data
    public func loadData(fileName: String) -> Data? {
        let fileURL = directoryURL.appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
    }

    /// Deletes image by fileName
    public func deleteImage(fileName: String) {
        let fileURL = directoryURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// URL for a specific file
    public func fileURL(for fileName: String) -> URL {
        directoryURL.appendingPathComponent(fileName)
    }
}
