import Foundation

extension FileManager {
    func allFiles(inDirectory directoryURL: URL) -> [URL] {
        guard let enumerator = enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }
        return enumerator.allObjects.compactMap { $0 as? URL }
    }
}
