import SwiftUI
import AppKit

public struct UninstallResultSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let result: UninstallResult

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: result.isCompleteSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(result.isCompleteSuccess ? .green : .orange)

            VStack(spacing: 6) {
                Text(result.isCompleteSuccess ? "Moved to Trash Successfully" : "Completed with Warnings")
                    .font(.system(size: 18, weight: .bold))

                Text("Cleaned \(result.successfulCount) items • Freed up \(result.formattedFreed)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            if !result.failures.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Could not move some items:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(result.failures, id: \.self) { failure in
                                Text("• \(failure)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            HStack(spacing: 12) {
                Button("Open Trash") {
                    if let trashURL = try? FileManager.default.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
                        NSWorkspace.shared.open(trashURL)
                    }
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 440)
    }
}
