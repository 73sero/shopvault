# ShopVault

> Self-hosted, encrypted shop & inventory tracker for iOS — your data never leaves your device.

ShopVault is a SwiftUI app for small businesses that want to track products, customers, orders, supplier deliveries and income — without sending anything to the cloud. All data lives in an encrypted SQLite database on your device, unlocked by Face ID. A companion macOS viewer lets you browse encrypted snapshot exports on your Mac.

**Built for:** Cafés, retail stores, freelancers, makers, and anyone running a small operation who values privacy.

## Features

- 🔒 **AES-256 encryption** — SQLCipher local database, Face ID unlock, no backend
- 📱 **iOS app** — Inventory, customer relationship management, order tracking, income recording
- 🖥️ **macOS viewer** — Browse encrypted `.shopvault` snapshots on your Mac
- 📊 **Dashboards** — Revenue, profit, top customers, low stock alerts, monthly charts
- 🎨 **Polished UI** — Dark glass-morphism, animated mesh backgrounds, smooth transitions
- 🌍 **Localized** — Currently English & German
- 🚀 **Onboarding** — Start with one of three industry templates (Café, Retail, Service) or empty
- 📤 **Encrypted exports** — Password-protected `.shopvault` snapshots, AES-256-GCM + PBKDF2 600k iterations

## Tech Stack

- SwiftUI + Combine (reactive MVVM)
- SQLite + SQLCipher (encrypted at rest)
- iOS Keychain (key storage)
- LocalAuthentication (Face ID / Touch ID)
- CryptoKit + CommonCrypto (AES-GCM, PBKDF2)
- Swift Charts (analytics)
- Zero third-party dependencies (except SQLCipher)

## Project Structure

```
ShopVault/
├── ShopVault/            ← Core SPM library (security, theme, base models)
├── ShopVaultApp/         ← Xcode iOS app
│   └── ShopVaultApp/
│       ├── App/          ← @main entry, notifications
│       ├── Database/     ← DatabaseManager, schema, seed data
│       ├── Models/       ← Domain models (Product, Order, Customer, ...)
│       ├── Repositories/ ← DB-access layer
│       ├── ViewModels/   ← MVVM view models (@MainActor)
│       ├── Views/        ← SwiftUI views
│       ├── Theme/        ← AppTheme, glass cards, gradients
│       ├── Security/     ← Encryption, PIN hashing, biometric auth
│       └── Services/     ← Export service
├── ShopVaultMac/         ← Standalone macOS snapshot viewer (SPM)
├── ShopVaultTests/       ← Unit tests
└── docs/                 ← Architecture, security, setup docs
```

## Build

### iOS app

Requirements: Xcode 16+, iOS 17+

```bash
open ShopVaultApp/ShopVaultApp.xcodeproj
# Set your own Apple Team ID in Signing & Capabilities, then ⌘R
```

Or via CLI:

```bash
xcodebuild -project ShopVaultApp/ShopVaultApp.xcodeproj \
           -scheme ShopVaultApp \
           -destination 'generic/platform=iOS Simulator' \
           build
```

### macOS viewer

Requirements: macOS 14+

```bash
cd ShopVaultMac
./build-app.sh
open "./build/ShopVault Viewer.app"
```

The script builds a proper `.app` bundle (with icon, Info.plist, ad-hoc signature). Move it to `/Applications/` to install.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                       SwiftUI Views                     │
│       (DashboardView, OrdersView, CustomersView...)     │
└──────────────────────────┬──────────────────────────────┘
                           │ @StateObject / @Published
┌──────────────────────────▼──────────────────────────────┐
│                       ViewModels                        │
│           (@MainActor, ObservableObject)                │
└──────────────────────────┬──────────────────────────────┘
                           │ async/await
┌──────────────────────────▼──────────────────────────────┐
│                      Repositories                       │
│   (ProductRepo, OrderRepo, CustomerRepo, IncomeRepo)    │
└──────────────────────────┬──────────────────────────────┘
                           │ SQL
┌──────────────────────────▼──────────────────────────────┐
│                    DatabaseManager                      │
│            SQLCipher (AES-256 encrypted)                │
└──────────────────────────┬──────────────────────────────┘
                           │
                       Keychain
                  (encryption keys)
```

## Snapshot Format

The encrypted export (`.shopvault`) is a JSON envelope:

```json
{
  "format": "shopvault-encrypted-export",
  "version": 1,
  "kdf": {
    "name": "PBKDF2-HMAC-SHA256",
    "iterations": 600000,
    "salt_base64": "...",
    "key_length_bytes": 32
  },
  "cipher": {
    "name": "AES-256-GCM",
    "payload_layout": "CryptoKit combined nonce + ciphertext + tag"
  },
  "payload_base64": "..."
}
```

The Mac viewer derives the AES key from the user-supplied passphrase using PBKDF2 (600k rounds, SHA-256), then decrypts the GCM-sealed payload. Decrypted data lives only in RAM — nothing is ever written to disk by the viewer.

## Contributing

PRs welcome! See [CONTRIBUTING.md](CONTRIBUTING.md). For security issues, please follow [SECURITY.md](SECURITY.md) instead of filing a public issue.

## License

MIT — see [LICENSE](LICENSE).
