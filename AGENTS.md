# AGENTS.md — Chuckaway

Native macOS uninstaller app built with Swift 6 and SwiftUI. Scans applications and deep-cleans associated residues in `~/Library` as well as Home/XDG dotfile directories (`~/.<app>`, `~/.config`, `~/.cache`, `~/.local/state`).

## Quick Reference & Commands
- **Platform**: macOS 14.0+ (Sonoma, Sequoia)
- **Toolchain**: Swift 6.0 (`Package.swift`), Swift Package Manager (SPM)
- **Dev Run**: `swift run`
- **Build Only**: `swift build`
- **Release Bundle (.app)**: `./scripts/build_app.sh` (produces `dist/Chuckaway.app`)
- **Launch Packaged App**: `open "dist/Chuckaway.app"`

---

## Safety Guardrails (CRITICAL)
Any AI agent modifying file-handling logic must strictly follow these invariants:
1. **Never Permanently Delete**: Always use `FileManager.default.trashItem(at:resultingItemURL:)`. Do NOT use `removeItem(at:)`. All operations must be recoverable via macOS Trash.
2. **Protect System Apps**: Never allow deletion of apps flagged with `isSystemApp` (e.g., in `/System/Applications` or Apple system bundles).
3. **Residue Scoping & Whitelist**: Restrict scanning strictly to user application residues inside `~/Library` and application-specific dotfiles/XDG paths in `~`. Never touch protected system/developer dotfiles (`.ssh`, `.git`, `.zshrc`, `.bashrc`, `.cargo`, `.npm`, `.Trash`, etc.). Never allow wildcard or recursive traversals targeting root `/`, `/System`, `/usr`, `/bin`.
4. **Non-blocking I/O**: File scanning and size calculation must run asynchronously off the main thread; update UI state only via `@MainActor`.

---

## Architecture & Codebase Map

Pattern: **MVVM** using Swift 6 Observation framework (`@Observable`).

```
Chuckaway/
├── Package.swift                             # SPM manifest (macOS v14, Swift 6 executable)
├── scripts/
│   └── build_app.sh                          # Compiles release binary & packages dist/Chuckaway.app
├── Resources/
│   └── AppIcon.icns                          # Application icon
└── Sources/Chuckaway/
    ├── ChuckawayApp.swift                    # App entry point (@main, WindowGroup)
    ├── Models/
    │   ├── AppModel.swift                    # App entity (bundleURL, bundleIdentifier, isSystemApp, residues)
    │   └── ResidueItem.swift                 # Residue item & category enum (Caches, Prefs, Containers, Dotfiles, etc.)
    ├── Services/
    │   ├── AppEraserViewModel.swift          # Main UI state (@Observable, @MainActor, sorting/filtering/orchestration)
    │   ├── AppScanner.swift                  # Scans /Applications and ~/Applications for .app bundles
    │   ├── ResidueScanner.swift              # Deep-scans ~/Library and Home dotfolders for bundle IDs and app tokens
    │   ├── UninstallerService.swift          # Executes safe uninstallation via FileManager.trashItem
    │   └── FileSystemHelper.swift            # Fast POSIX fts directory sizing and path formatting
    └── Views/
        ├── ContentView.swift                 # Main split layout (App list sidebar + Detail pane)
        ├── AppRowView.swift                  # List row showing app icon, name, size, and system badge
        ├── DropZoneView.swift                # Drag-and-drop zone for external .app bundles
        ├── ResidueDetailView.swift           # Residue item checklist, total reclaimable size, and Action button
        └── UninstallResultSheet.swift        # Post-uninstall summary modal showing trashed files
```

---

## Coding Conventions
- **State Management**: Use `@Observable` for classes (Observation framework) instead of legacy `ObservableObject` / `@Published`.
- **Concurrency**: Adhere to Swift 6 strict concurrency rules. Mark UI view models and SwiftUI views with `@MainActor`. Use structured concurrency (`Task`, `async/await`) for disk scanning.
- **UI Design**: Native macOS aesthetic (Vibrant materials, SF Symbols, proper spacing, `NavigationSplitView`, keyboard shortcuts where applicable).
- **Zero Heavy Dependencies**: Keep the project pure Swift/AppKit/SwiftUI with zero external third-party SPM dependencies unless explicitly requested.
