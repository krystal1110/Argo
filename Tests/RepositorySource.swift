import Foundation

func repositoryRoot(for filePath: String) -> URL {
    URL(fileURLWithPath: filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

func repositorySource(_ relativePath: String, from filePath: String = #filePath) throws -> String {
    let root = repositoryRoot(for: filePath)
    let directURL = root.appendingPathComponent(relativePath)
    if FileManager.default.fileExists(atPath: directURL.path) {
        return try String(contentsOf: directURL, encoding: .utf8)
    }

    for fallback in vendoredSourceFallbacks(for: relativePath) {
        let fallbackURL = root.appendingPathComponent(fallback)
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            return try String(contentsOf: fallbackURL, encoding: .utf8)
        }
    }

    return try String(contentsOf: directURL, encoding: .utf8)
}

private func vendoredSourceFallbacks(for relativePath: String) -> [String] {
    if relativePath.hasPrefix("Argo/ghostty/") {
        return ["Vendor/GhosttyResources/" + relativePath.dropPrefix("Argo/")]
    }
    if relativePath.hasPrefix("Argo/terminfo/") {
        return ["Vendor/GhosttyResources/" + relativePath.dropPrefix("Argo/")]
    }
    if relativePath.hasPrefix("Argo/") {
        return ["Argo/Vendor/LineyCompat/" + relativePath.dropPrefix("Argo/")]
    }
    return []
}

private extension String {
    func dropPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }
}
