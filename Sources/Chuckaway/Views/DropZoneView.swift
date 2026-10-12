import SwiftUI
import UniformTypeIdentifiers

public struct DropZoneView: View {
    @Bindable var viewModel: AppEraserViewModel
    @State private var isTargeted: Bool = false

    public var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                    )

                VStack(spacing: 14) {
                    Image(systemName: isTargeted ? "arrow.down.app.fill" : "app.dashed")
                        .font(.system(size: 48))
                        .foregroundStyle(isTargeted ? Color.accentColor : .secondary)
                        .scaleEffect(isTargeted ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTargeted)

                    VStack(spacing: 4) {
                        Text(isTargeted ? "Drop Application Here" : "Drag & Drop an Application")
                            .font(.system(size: 16, weight: .bold))

                        Text("Drop any .app file to analyze and clean its leftover files")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button {
                            viewModel.browseAppManually()
                        } label: {
                            Label("Browse .app...", systemImage: "folder")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                    .padding(.top, 6)
                }
                .padding(32)
            }
            .frame(maxWidth: 420, maxHeight: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
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
    }
}
