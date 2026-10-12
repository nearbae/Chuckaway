import Foundation
import SwiftUI

public enum ResidueCategory: String, CaseIterable, Identifiable, Sendable {
    case binary = "Application Bundle"
    case applicationSupport = "Application Support"
    case caches = "Caches"
    case preferences = "Preferences"
    case savedState = "Saved Application State"
    case containers = "Containers"
    case groupContainers = "Group Containers"
    case logs = "Logs"
    case webKitAndStorage = "WebKit & Storage"
    case launchAgents = "Launch Agents"
    case dotFilesAndData = "Dotfiles & Local Data"
    case other = "Other Residues"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .binary: return "app.badge.fill"
        case .applicationSupport: return "folder.fill"
        case .caches: return "bolt.horizontal.fill"
        case .preferences: return "gearshape.fill"
        case .savedState: return "clock.arrow.circlepath"
        case .containers: return "shippingbox.fill"
        case .groupContainers: return "square.stack.3d.up.fill"
        case .logs: return "doc.plaintext.fill"
        case .webKitAndStorage: return "globe"
        case .launchAgents: return "play.circle.fill"
        case .dotFilesAndData: return "terminal.fill"
        case .other: return "doc.fill"
        }
    }

    public var color: Color {
        switch self {
        case .binary: return .blue
        case .applicationSupport: return .orange
        case .caches: return .purple
        case .preferences: return .mint
        case .savedState: return .indigo
        case .containers: return .cyan
        case .groupContainers: return .teal
        case .logs: return .gray
        case .webKitAndStorage: return .yellow
        case .launchAgents: return .pink
        case .dotFilesAndData: return .brown
        case .other: return .secondary
        }
    }
}

public struct ResidueItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let category: ResidueCategory
    public var size: Int64
    public var isSelected: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        category: ResidueCategory,
        size: Int64,
        isSelected: Bool = true
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.category = category
        self.size = size
        self.isSelected = isSelected
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if url.path.hasPrefix(home) {
            return "~" + url.path.dropFirst(home.count)
        }
        return url.path
    }
}
