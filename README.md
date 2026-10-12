# Chuckaway 🧹

Aplikasi native macOS untuk membersihkan dan meng-uninstall aplikasi secara tuntas, termasuk seluruh file sisa (`~/Library`: Application Support, Caches, Preferences, Containers, Logs, Saved Application State, WebKit/HTTPStorages, LaunchAgents) serta folder data/CLI dotfiles (`~/.<app>`, `~/.config`, `~/.cache`, `~/.local/state`).

![App Icon](Resources/AppIcon.icns)

## Fitur Utama

- 🔍 **Deteksi Aplikasi Otomatis**: Memindai seluruh aplikasi di `/Applications` dan `~/Applications`.
- 📂 **Browse & Drag-and-Drop**: Pilih `.app` mana saja atau seret langsung file `.app` ke dalam jendela aplikasi.
- 🧬 **Deep Residue & Dotfiles Detection**: Menelusuri seluruh file sisa di `~/Library` serta dotfiles/XDG data di Home direktori (seperti local AI models, CLI cache) menggunakan Bundle Identifier dan token nama aplikasi.
- 🔒 **Proteksi Aplikasi Sistem**: Menandai dan mengunci aplikasi bawaan macOS agar tidak terhapus tanpa sengaja.
- 🗑️ **Safe Trash Removal**: Memindahkan file ke **macOS Trash** via `FileManager.trashItem`, sehingga aman dan bisa di-restore kapan saja jika diperlukan.
- ⚡ **Native Performa Tinggi**: Dibuat dengan Swift 6 & SwiftUI murni dengan penelusuran kernel POSIX `fts` secepat kilat tanpa runtime berat seperti Electron.

## Cara Menjalankan

### Opsi 1: Menjalankan Aplikasi Langsung
Buka aplikasi yang sudah di-bundle di folder `dist/`:
```bash
open "dist/Chuckaway.app"
```

Atau copy `dist/Chuckaway.app` ke folder `/Applications` Anda:
```bash
cp -R "dist/Chuckaway.app" /Applications/
```

### Opsi 2: Build Ulang dari Source
Untuk meng-compile ulang setelah melakukan perubahan:
```bash
./scripts/build_app.sh
```

Atau jalankan langsung dalam mode development:
```bash
swift run
```

