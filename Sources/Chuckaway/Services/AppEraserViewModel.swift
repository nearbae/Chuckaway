import Foundation
import SwiftUI
import AppKit

public enum AppSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case size = "Size"

    public var id: String { rawValue }
}

public enum AppFilterCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case user = "User"
    case system = "System"

    public var id: String { rawValue }
}

@Observable
@MainActor
public final class AppEraserViewModel {
    public var apps: [AppModel] = []
    public var selectedApp: AppModel?
    public var searchText: String = ""
    public var sortOption: AppSortOption = .name
    public var filterCategory: AppFilterCategory = .all

    public var isLoadingApps: Bool = false
    public var isUninstalling: Bool = false
    public var lastUninstallResult: UninstallResult?
    public var showResultSheet: Bool = false
    public var showConfirmAlert: Bool = false

    public init() {}

    public var userAppsCount: Int {
        apps.filter { !$0.isSystemApp }.count
    }

    public var systemAppsCount: Int {
        apps.filter { $0.isSystemApp }.count
    }

    public var filteredApps: [AppModel] {
        apps.filter { app in
            switch filterCategory {
            case .all:
                break
            case .user:
                if app.isSystemApp { return false }
            case .system:
                if !app.isSystemApp { return false }
            }

            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
            let query = searchText.lowercased()
            return app.name.lowercased().contains(query) ||
                (app.bundleIdentifier?.lowercased().contains(query) ?? false)
        }
        .sorted {
            switch sortOption {
            case .name:
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            case .size:
                return $0.appSize > $1.appSize
            }
        }
    }

    public func loadApps() {
        guard !isLoadingApps else { return }
        isLoadingApps = true

        Task {
            let scanned = await AppScanner.shared.scanInstalledApps()
            await MainActor.run {
                self.apps = scanned
                self.isLoadingApps = false
                if self.selectedApp == nil, let first = self.filteredApps.first {
                    self.selectApp(first)
                }
            }
        }
    }

    public func selectApp(_ app: AppModel) {
        selectedApp = app
        if app.residues.isEmpty && !app.isScanningResidues {
            scanResidues(for: app)
        }
    }

    public func scanResidues(for app: AppModel) {
        guard let index = apps.firstIndex(where: { $0.id == app.id }) else { return }

        // 1. Instant detection (< 5ms)
        let items = ResidueScanner.shared.scanResiduesFast(for: app)
        apps[index].residues = items
        apps[index].isScanningResidues = true
        if selectedApp?.id == app.id {
            selectedApp?.residues = items
            selectedApp?.isScanningResidues = true
        }

        // 2. Compute sizes concurrently in parallel background task group
        Task.detached(priority: .userInitiated) {
            await withTaskGroup(of: (UUID, Int64, ResidueCategory).self) { group in
                for item in items {
                    group.addTask {
                        let size = FileSystemHelper.calculateSize(at: item.url)
                        return (item.id, size, item.category)
                    }
                }

                for await (itemId, size, category) in group {
                    await MainActor.run {
                        if let appIdx = self.apps.firstIndex(where: { $0.id == app.id }) {
                            if let itemIdx = self.apps[appIdx].residues.firstIndex(where: { $0.id == itemId }) {
                                self.apps[appIdx].residues[itemIdx].size = size
                                if category == .binary {
                                    self.apps[appIdx].appSize = size
                                }
                            }
                        }
                        if self.selectedApp?.id == app.id {
                            if let itemIdx = self.selectedApp?.residues.firstIndex(where: { $0.id == itemId }) {
                                self.selectedApp?.residues[itemIdx].size = size
                                if category == .binary {
                                    self.selectedApp?.appSize = size
                                }
                            }
                        }
                    }
                }
            }

            await MainActor.run {
                if let appIdx = self.apps.firstIndex(where: { $0.id == app.id }) {
                    self.apps[appIdx].isScanningResidues = false
                }
                if self.selectedApp?.id == app.id {
                    self.selectedApp?.isScanningResidues = false
                }
            }
        }
    }

    public func toggleResidue(id: UUID) {
        guard var app = selectedApp else { return }
        if let idx = app.residues.firstIndex(where: { $0.id == id }) {
            app.residues[idx].isSelected.toggle()
            selectedApp = app
            if let listIdx = apps.firstIndex(where: { $0.id == app.id }) {
                apps[listIdx].residues = app.residues
            }
        }
    }

    public func setAllResiduesSelected(_ selected: Bool) {
        guard var app = selectedApp else { return }
        for i in app.residues.indices {
            // Keep binary checked if selecting all, or uncheck all
            app.residues[i].isSelected = selected
        }
        selectedApp = app
        if let listIdx = apps.firstIndex(where: { $0.id == app.id }) {
            apps[listIdx].residues = app.residues
        }
    }

    public func browseAppManually() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.prompt = "Select App"
        panel.message = "Choose an application (.app) to inspect and uninstall"

        if panel.runModal() == .OK, let url = panel.url {
            handleCustomAppURL(url)
        }
    }

    public func handleCustomAppURL(_ url: URL) {
        guard url.pathExtension == "app" else { return }
        if let existing = apps.first(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
            selectApp(existing)
            return
        }

        if let newApp = AppScanner.shared.parseApp(at: url) {
            apps.insert(newApp, at: 0)
            selectApp(newApp)
        }
    }

    public func performUninstall() {
        guard let app = selectedApp else { return }
        isUninstalling = true

        let itemsToTrash = app.residues.filter { $0.isSelected }

        Task {
            do {
                let result = try await UninstallerService.shared.trashItems(itemsToTrash)
                await MainActor.run {
                    self.lastUninstallResult = result
                    self.isUninstalling = false
                    self.showResultSheet = true

                    // Remove or update the app from the list if the main bundle was deleted
                    let trashedBinary = itemsToTrash.contains(where: { $0.category == .binary })
                    if trashedBinary {
                        self.apps.removeAll(where: { $0.id == app.id })
                        self.selectedApp = self.filteredApps.first
                        if let next = self.selectedApp {
                            self.scanResidues(for: next)
                        }
                    } else {
                        // Refresh residues
                        self.scanResidues(for: app)
                    }
                }
            } catch {
                await MainActor.run {
                    self.isUninstalling = false
                    self.lastUninstallResult = UninstallResult(
                        totalBytesFreed: 0,
                        successfulCount: 0,
                        failures: [error.localizedDescription]
                    )
                    self.showResultSheet = true
                }
            }
        }
    }
}
