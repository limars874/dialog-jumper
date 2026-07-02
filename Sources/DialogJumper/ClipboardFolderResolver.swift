import Foundation

struct ClipboardFolderResolver {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func resolve(rawString: String?) -> URL? {
        guard let rawString else {
            return nil
        }

        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        guard let candidate = candidateURL(from: trimmed) else {
            return nil
        }

        return existingFolderURL(for: candidate)
    }

    private func candidateURL(from text: String) -> URL? {
        if let url = URL(string: text), url.isFileURL {
            return url.standardizedFileURL
        }

        let expanded = (text as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else {
            return nil
        }

        return URL(fileURLWithPath: expanded).standardizedFileURL
    }

    private func existingFolderURL(for url: URL) -> URL? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }

        if isDirectory.boolValue {
            return url
        }

        return url.deletingLastPathComponent().standardizedFileURL
    }
}
