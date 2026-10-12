import SwiftUI
import UniformTypeIdentifiers

public struct ContentView: View {
    @State private var viewModel = AppEraserViewModel()
    @State private var isWindowDropTargeted: Bool = false

    public init() {}

    public var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 400)
        } detail: {
            detailContent
        }
        .searchable(text: $viewModel.searchText, prompt: "Search applications...")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("Sort By", selection: $viewModel.sortOption) {
                        ForEach(AppSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }

                Button {
                    viewModel.browseAppManually()
                } label: {
                    Label("Browse .app", systemImage: "plus.rectangle.on.folder")
                }
                .help("Browse application file (.app)")

                Button {
                    viewModel.loadApps()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh installed applications")
            }
        }
        .onAppear {
            viewModel.loadApps()
        }
        .onDrop(of: [.fileURL], isTargeted: $isWindowDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url, url.pathExtension == "app" {
                    Task { @MainActor in
                        viewModel.handleCustomAppURL(url)
                    }
                }
            }
            return true
        }
        .sheet(isPresented: $viewModel.showResultSheet) {
            if let result = viewModel.lastUninstallResult {
                UninstallResultSheet(result: result)
            }
        }
    }

    // MARK: - Sidebar
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Segmented Category Filter (All, User, System)
            Picker("Filter", selection: $viewModel.filterCategory) {
                Text("All (\(viewModel.apps.count))").tag(AppFilterCategory.all)
                Text("User (\(viewModel.userAppsCount))").tag(AppFilterCategory.user)
                Text("System (\(viewModel.systemAppsCount))").tag(AppFilterCategory.system)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            if viewModel.isLoadingApps && viewModel.apps.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Scanning applications...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No applications found")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.filteredApps, selection: $viewModel.selectedApp) { app in
                    AppRowView(app: app, isSelected: viewModel.selectedApp?.id == app.id)
                        .tag(app)
                        .onTapGesture {
                            viewModel.selectApp(app)
                        }
                }
                .listStyle(.sidebar)
                .onChange(of: viewModel.selectedApp?.id) { _, newId in
                    if let newId, let app = viewModel.apps.first(where: { $0.id == newId }) {
                        viewModel.selectApp(app)
                    }
                }
            }

            Divider()

            // Status bar at bottom of sidebar
            HStack {
                Text("\(viewModel.filteredApps.count) applications")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Spacer()

                if viewModel.isLoadingApps {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    // MARK: - Detail
    @ViewBuilder
    private var detailContent: some View {
        if let selectedApp = viewModel.selectedApp {
            ResidueDetailView(viewModel: viewModel, app: selectedApp)
        } else {
            DropZoneView(viewModel: viewModel)
        }
    }
}
