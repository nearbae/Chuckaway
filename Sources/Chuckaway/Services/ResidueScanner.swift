import Foundation

public final class ResidueScanner: Sendable {
    public static let shared = ResidueScanner()

    public func scanResiduesFast(for app: AppModel) -> [ResidueItem] {
        var items: [ResidueItem] = []
        var discoveredPaths: Set<String> = []

        // 1. Binary bundle itself
        items.append(
            ResidueItem(
                url: app.url,
                name: app.url.lastPathComponent,
                category: .binary,
                size: 0,
                isSelected: true
            )
        )
        discoveredPaths.insert(app.url.standardizedFileURL.path)

        // 2. Identify search tokens
        let bundleId = app.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let appName = app.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawFileName = app.url.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)

        var directTokens: Set<String> = []
        if let bundleId, !bundleId.isEmpty {
            directTokens.insert(bundleId)
            // Extract significant domain/app tokens from bundle identifier (e.g., com.nousresearch.hermes.setup -> hermes)
            let ignoredParts: Set<String> = ["com", "org", "net", "app", "io", "co", "dev", "ai", "setup", "macos", "osx"]
            let parts = bundleId.components(separatedBy: ".")
            for part in parts {
                let trimmedPart = part.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if trimmedPart.count >= 3 && !ignoredParts.contains(trimmedPart) {
                    directTokens.insert(trimmedPart)
                }
            }
        }
        if appName.count >= 3 {
            directTokens.insert(appName)
            directTokens.insert(appName.replacingOccurrences(of: " ", with: ""))
            directTokens.insert(appName.lowercased())
            directTokens.insert(appName.replacingOccurrences(of: " ", with: "").lowercased())
        }
        if rawFileName.count >= 3 {
            directTokens.insert(rawFileName)
            directTokens.insert(rawFileName.replacingOccurrences(of: " ", with: ""))
            directTokens.insert(rawFileName.lowercased())
        }

        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library")

        // Protected system/dev dotfiles that should NEVER be scanned or deleted
        let protectedDotNames: Set<String> = [
            ".trash", ".ssh", ".gnupg", ".git", ".config", ".cache", ".local",
            ".zshrc", ".bashrc", ".bash_profile", ".zprofile", ".profile",
            ".zsh_history", ".bash_history", ".gitconfig", ".vimrc", ".npm",
            ".cargo", ".rustup", ".gemini", ".aws", ".kube", ".docker", ".conda",
            ".subversion", ".pki", ".vscode", ".android", ".gradle"
        ]

        // 3. Direct probe checks (AppZapper style - instant 0.001s)
        for token in directTokens {
            var probes: [(URL, ResidueCategory)] = [
                (library.appendingPathComponent("Application Support/\(token)"), .applicationSupport),
                (library.appendingPathComponent("Caches/\(token)"), .caches),
                (library.appendingPathComponent("Preferences/\(token).plist"), .preferences),
                (library.appendingPathComponent("Saved Application State/\(token).savedState"), .savedState),
                (library.appendingPathComponent("Containers/\(token)"), .containers),
                (library.appendingPathComponent("Group Containers/\(token)"), .groupContainers),
                (library.appendingPathComponent("Logs/\(token)"), .logs),
                (library.appendingPathComponent("WebKit/\(token)"), .webKitAndStorage),
                (library.appendingPathComponent("HTTPStorages/\(token)"), .webKitAndStorage),
                (library.appendingPathComponent("LaunchAgents/\(token).plist"), .launchAgents)
            ]

            // Check Home dotfolders & XDG data for developer/AI/CLI tools (e.g. ~/.hermes, ~/.config/hermes, ~/.local/state/hermes)
            if !token.contains(".") && token.count >= 3 {
                let tokenLower = token.lowercased()
                let dotName = ".\(tokenLower)"
                if !protectedDotNames.contains(dotName) {
                    probes.append((home.appendingPathComponent(dotName), .dotFilesAndData))
                }
                probes.append((home.appendingPathComponent(".config/\(tokenLower)"), .dotFilesAndData))
                probes.append((home.appendingPathComponent(".cache/\(tokenLower)"), .caches))
                probes.append((home.appendingPathComponent(".local/share/\(tokenLower)"), .dotFilesAndData))
                probes.append((home.appendingPathComponent(".local/state/\(tokenLower)"), .dotFilesAndData))
            }

            for (url, category) in probes {
                let path = url.standardizedFileURL.path
                guard !discoveredPaths.contains(path) else { continue }
                if fileManager.fileExists(atPath: path) {
                    discoveredPaths.insert(path)
                    items.append(
                        ResidueItem(
                            url: url,
                            name: url.lastPathComponent,
                            category: category,
                            size: 0,
                            isSelected: true
                        )
                    )
                }
            }
        }

        // 4. Quick 1-level scan of Preferences & Saved Application State for prefix matches
        let shallowLocations: [(URL, ResidueCategory)] = [
            (library.appendingPathComponent("Preferences"), .preferences),
            (library.appendingPathComponent("Saved Application State"), .savedState),
            (library.appendingPathComponent("LaunchAgents"), .launchAgents)
        ]

        let searchTokensLower = directTokens.map { $0.lowercased() }

        for (dir, category) in shallowLocations {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for fileURL in contents {
                let name = fileURL.lastPathComponent
                let nameLower = name.lowercased()
                let path = fileURL.standardizedFileURL.path

                guard !discoveredPaths.contains(path) else { continue }

                var isMatch = false
                for token in searchTokensLower {
                    if nameLower.hasPrefix(token) || nameLower.contains(token) {
                        isMatch = true
                        break
                    }
                }

                if isMatch {
                    discoveredPaths.insert(path)
                    items.append(
                        ResidueItem(
                            url: fileURL,
                            name: name,
                            category: category,
                            size: 0,
                            isSelected: true
                        )
                    )
                }
            }
        }

        return items
    }
}
