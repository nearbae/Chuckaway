import SwiftUI
import AppKit

public struct ResidueDetailView: View {
    @Bindable var viewModel: AppEraserViewModel
    let app: AppModel

    @State private var hoveredItemId: UUID?

    private var currentApp: AppModel {
        viewModel.selectedApp ?? app
    }

    private var selectedResidues: [ResidueItem] {
        currentApp.residues.filter { $0.isSelected }
    }

    private var selectedTotalBytes: Int64 {
        selectedResidues.reduce(0) { $0 + $1.size }
    }

    private var groupedResidues: [(ResidueCategory, [ResidueItem])] {
        let dict = Dictionary(grouping: currentApp.residues) { $0.category }
        return ResidueCategory.allCases.compactMap { cat in
            if let list = dict[cat], !list.isEmpty {
                return (cat, list)
            }
            return nil
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top App Header
            headerView
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // System App Warning if applicable
            if currentApp.isSystemApp {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(.orange)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Protected System Application")
                            .font(.system(size: 13, weight: .bold))
                        Text("This is an internal or core macOS component. Uninstalling system components is restricted for system safety.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.1))
                Divider()
            }

            // Residue list or loading state
            if currentApp.isScanningResidues && currentApp.residues.isEmpty {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Scanning associated files, caches & preferences...")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(groupedResidues, id: \.0) { category, items in
                            categorySection(category: category, items: items)
                        }
                    }
                    .padding(24)
                }
            }

            Divider()

            // Bottom Action Footer
            footerView
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: $viewModel.showConfirmAlert,
            titleVisibility: .visible
        ) {
            Button("Move \(selectedResidues.count) Items to Trash", role: .destructive) {
                viewModel.performUninstall()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to move the selected files (\(ByteCountFormatter.string(fromByteCount: selectedTotalBytes, countStyle: .file))) to Trash? You can restore them from Trash if needed.")
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 16) {
            Image(nsImage: currentApp.icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.18), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(currentApp.name)
                        .font(.system(size: 20, weight: .bold))

                    if let version = currentApp.version, !version.isEmpty {
                        Text("v\(version)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .separatorColor).opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                if let bundleId = currentApp.bundleIdentifier {
                    Text(bundleId)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Text(currentApp.url.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([currentApp.url])
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Category Section
    private func categorySection(category: ResidueCategory, items: [ResidueItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .foregroundStyle(category.color)
                Text(category.rawValue)
                    .font(.system(size: 13, weight: .bold))
                Text("(\(items.count))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer()

                let catSize = items.reduce(0) { $0 + $1.size }
                Text(ByteCountFormatter.string(fromByteCount: catSize, countStyle: .file))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 1) {
                ForEach(items) { item in
                    residueRow(item: item)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Residue Row
    private func residueRow(item: ResidueItem) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { item.isSelected },
                set: { _ in viewModel.toggleResidue(id: item.id) }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            .disabled(currentApp.isSystemApp && item.category == .binary)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(item.displayPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if item.size > 0 {
                Text(item.formattedSize)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            } else if currentApp.isScanningResidues {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Text(item.formattedSize)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .help("Reveal in Finder")
            .opacity(hoveredItemId == item.id ? 1 : 0.4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onHover { isHovered in
            if isHovered {
                hoveredItemId = item.id
            } else if hoveredItemId == item.id {
                hoveredItemId = nil
            }
        }
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(selectedResidues.count) items selected")
                        .font(.system(size: 12, weight: .semibold))
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: selectedTotalBytes, countStyle: .file))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }

                Text("Safe removal: Selected files will be moved to macOS Trash")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                Button("Select All") {
                    viewModel.setAllResiduesSelected(true)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Deselect All") {
                    viewModel.setAllResiduesSelected(false)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    viewModel.showConfirmAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                        Text("Move to Trash")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.regular)
                .disabled(selectedResidues.isEmpty || (currentApp.isSystemApp && selectedResidues.allSatisfy { $0.category == .binary }))
            }
        }
    }
}
