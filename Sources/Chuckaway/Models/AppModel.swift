import Foundation
import AppKit

public struct AppModel: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let url: URL
    public let bundleIdentifier: String?
    public let version: String?
    public let isSystemApp: Bool
    public var appSize: Int64
    public var residues: [ResidueItem]
    public var isScanningResidues: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        bundleIdentifier: String? = nil,
        version: String? = nil,
        isSystemApp: Bool = false,
        appSize: Int64 = 0,
        residues: [ResidueItem] = [],
        isScanningResidues: Bool = false
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.isSystemApp = isSystemApp
        self.appSize = appSize
        self.residues = residues
        self.isScanningResidues = isScanningResidues
    }

    public var totalSize: Int64 {
        let selectedResidueSize = residues.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
        return appSize + selectedResidueSize
    }

    public var allResiduesSize: Int64 {
        return residues.reduce(0) { $0 + $1.size }
    }

    public var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(url)
    }

    public static func == (lhs: AppModel, rhs: AppModel) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}
