import Foundation
import AppKit

public final class AppScanner: Sendable {
    public static let shared = AppScanner()

    private let protectedBundleIdentifiers: Set<String> = [
        "com.apple.finder",
        "com.apple.Safari",
        "com.apple.systempreferences",
        "com.apple.Terminal",
        "com.apple.ActivityMonitor",
        "com.apple.AppStore",
        "com.apple.Preview",
        "com.apple.QuickTimePlayerX",
        "com.apple.TextEdit"
    ]

    public func scanInstalledApps() async -> [AppModel] {
        var results: [AppModel] = []
        var seenURLs: Set<URL> = []

        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser

        // 1. Direct priority scan directories (depth 3 to catch nested web apps & projects)
        let priorityDirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            homeDir.appendingPathComponent("Applications"),
            homeDir.appendingPathComponent("Downloads"),
            homeDir.appendingPathComponent("Desktop"),
            homeDir.appendingPathComponent("Documents")
        ]

        for dir in priorityDirs {
            guard fileManager.fileExists(atPath: dir.path) else { continue }
            scanDirectory(dir, depth: 3, seenURLs: &seenURLs, results: &results)
        }

        // 2. Query Spotlight for any apps installed in other custom folders
        let spotlightURLs = querySpotlightForApps()
        for url in spotlightURLs {
            let standardized = url.standardizedFileURL
            if !seenURLs.contains(standardized) && isValidAppPath(standardized.path) {
                seenURLs.insert(standardized)
                if let app = parseApp(at: url) {
                    results.append(app)
                }
            }
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func scanDirectory(_ dir: URL, depth: Int, seenURLs: inout Set<URL>, results: inout [AppModel]) {
        guard depth >= 0 else { return }
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isApplicationKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in contents {
            if url.pathExtension == "app" {
                let standardized = url.standardizedFileURL
                if !seenURLs.contains(standardized) && isValidAppPath(standardized.path) {
                    seenURLs.insert(standardized)
                    if let app = parseApp(at: url) {
                        results.append(app)
                    }
                }
            } else if depth > 0 {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: url.path, isDirectory: &isDir),
                   isDir.boolValue,
                   !url.lastPathComponent.hasPrefix("."),
                   !url.path.contains(".build"),
                   !url.path.contains(".git"),
                   !url.path.contains("node_modules") {
                    scanDirectory(url, depth: depth - 1, seenURLs: &seenURLs, results: &results)
                }
            }
        }
    }

    private func querySpotlightForApps() -> [URL] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["kMDItemContentType == 'com.apple.application-bundle'"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard let output = String(data: data, encoding: .utf8) else { return [] }
            let lines = output.components(separatedBy: .newlines)

            return lines.compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return URL(fileURLWithPath: trimmed)
            }
        } catch {
            return []
        }
    }

    private func isValidAppPath(_ path: String) -> Bool {
        // Exclude Trash, Dev Platforms, CommandLineTools, DerivedData, internal build
        if path.contains("/.Trash/") ||
            path.contains("/Contents/Developer/") ||
            path.contains("/Library/Developer/") ||
            path.contains("/DerivedData/") ||
            path.contains("/.build/") ||
            path.contains("/.git/") {
            return false
        }
        // Exclude internal helper apps inside other .app bundles
        if path.contains(".app/Contents/") {
            return false
        }
        // Exclude /Library/ and /System/Library/ system services and root daemons
        if path.hasPrefix("/Library/") || path.hasPrefix("/System/Library/") {
            return false
        }
        // Exclude ~/Library/ internal data caches and scripts
        if path.contains("/Library/Application Support/") ||
            path.contains("/Library/Application Scripts/") ||
            path.contains("/Library/Caches/") {
            return false
        }
        // Exclude Homebrew internals
        if path.contains("/Cellar/") || path.contains("/Homebrew/") {
            return false
        }
        return true
    }

    public func parseApp(at url: URL) -> AppModel? {
        guard url.pathExtension == "app" else { return nil }
        guard let bundle = Bundle(url: url) else {
            let fallbackName = url.deletingPathExtension().lastPathComponent
            return AppModel(name: fallbackName, url: url)
        }

        let bundleId = bundle.bundleIdentifier
        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String)

        let isSystemApp: Bool
        if url.path.hasPrefix("/System/") {
            isSystemApp = true
        } else if let bundleId, protectedBundleIdentifiers.contains(bundleId) {
            isSystemApp = true
        } else {
            isSystemApp = false
        }

        return AppModel(
            name: displayName,
            url: url,
            bundleIdentifier: bundleId,
            version: version,
            isSystemApp: isSystemApp,
            appSize: 0,
            residues: [],
            isScanningResidues: false
        )
    }
}
