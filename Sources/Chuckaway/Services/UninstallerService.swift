import Foundation
import AppKit

public struct UninstallResult: Sendable {
    public let totalBytesFreed: Int64
    public let successfulCount: Int
    public let failures: [String]

    public var isCompleteSuccess: Bool {
        failures.isEmpty
    }

    public var formattedFreed: String {
        ByteCountFormatter.string(fromByteCount: totalBytesFreed, countStyle: .file)
    }
}

public final class UninstallerService: Sendable {
    public static let shared = UninstallerService()

    public func trashItems(_ items: [ResidueItem]) async throws -> UninstallResult {
        var freedBytes: Int64 = 0
        var successCount = 0
        var errors: [String] = []

        let fileManager = FileManager.default

        // 0. If the app is currently running, gracefully terminate it so files aren't locked
        if let binaryItem = items.first(where: { $0.category == .binary }) {
            if let bundle = Bundle(url: binaryItem.url), let bundleId = bundle.bundleIdentifier {
                let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
                for runningApp in runningApps {
                    runningApp.terminate()
                }
            }
        }

        for item in items where item.isSelected {
            var trashed = false

            // 1. First try standard FileManager.trashItem
            do {
                var resultingURL: NSURL?
                try fileManager.trashItem(at: item.url, resultingItemURL: &resultingURL)
                trashed = true
            } catch {
                // 2. If permission error, try via Finder or Administrator prompt (with strict timeout)
                if trashItemWithAdminFallback(url: item.url) {
                    trashed = true
                } else {
                    errors.append("\(item.name): \(error.localizedDescription)")
                }
            }

            if trashed {
                freedBytes += item.size
                successCount += 1
            }
        }

        return UninstallResult(
            totalBytesFreed: freedBytes,
            successfulCount: successCount,
            failures: errors
        )
    }

    private func trashItemWithAdminFallback(url: URL) -> Bool {
        let path = url.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")

        // 1. Try Finder delete with 3-second timeout (avoids 120s hang on unresponsive Finder)
        let finderScript = """
        with timeout of 3 seconds
            tell application "Finder"
                delete (POSIX file "\(path)" as alias)
            end tell
        end timeout
        """
        if let script = NSAppleScript(source: finderScript) {
            var errorInfo: NSDictionary?
            script.executeAndReturnError(&errorInfo)
            if errorInfo == nil {
                return true
            }
        }

        // 2. Try with administrator privileges (with timeout)
        let homeTrash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").path
        let adminScript = """
        with timeout of 6 seconds
            do shell script "mv \\"\(path)\\" \\"\(homeTrash)\\"" with administrator privileges
        end timeout
        """
        if let script = NSAppleScript(source: adminScript) {
            var errorInfo: NSDictionary?
            script.executeAndReturnError(&errorInfo)
            if errorInfo == nil {
                return true
            }
        }

        return false
    }
}
