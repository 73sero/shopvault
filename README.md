# ShopVault

> Self-hosted, encrypted shop & inventory tracker for iOS — your data never leaves your device.

ShopVault is a SwiftUI app for small businesses that want to track products, customers, orders, supplier deliveries and income — without sending anything to the cloud. All data lives in an encrypted SQLite database on your device, unlocked by Face ID. A companion macOS viewer lets you browse encrypted snapshot exports on your Mac.

**Built for:** Cafés, retail stores, freelancers, makers, and anyone running a small operation who values privacy.

## Features

### Core
- 🔒 **AES-256 encryption** — SQLCipher local database, Face ID / Touch ID unlock, configurable PIN length (4/6/8 digits), no backend
- 📱 **Native iOS app** — SwiftUI + MVVM, dark mode, glass-morphism UI with animated mesh background
- 🖥️ **Standalone macOS viewer** — Browse encrypted `.shopvault` snapshots offline; hide irrelevant rows locally without touching the source file
- 📤 **Encrypted exports** — Password-protected `.shopvault` snapshots, AES-256-GCM + PBKDF2-HMAC-SHA256 (600 000 iterations)
- 🌍 **Localized** — English & German built-in; add more via `.lproj/Localizable.strings`

### Shop module
- 🛒 **Orders** — Multi-line cart, customer assignment, discount with note, automatic stock decrement, automatic income entry
- ✏️ **Order editing** — Adjust quantities or remove items after the fact; stock and income re-sync atomically
- 🗑️ **Order deletion** — Restores stock and removes the linked income entry in one transaction
- 👥 **Customers** — Full CRUD with PII (phone, email, address) field-encrypted before persistence; per-customer order history and lifetime spend
- 📦 **Inventory** — Add / edit / delete / hide products; favorites; low-stock and out-of-stock filters; live stock-fill bar visualization
- 🚚 **Supplier deliveries** — Record incoming stock with cost, automatically update inventory; list view with swipe-to-delete and stock restoration

### Finance module
- 💶 **Income tracking** — Manual entries plus auto-created entries from orders; categorized; full search and date filtering
- 📊 **Dashboard** — Monthly revenue, profit margin, top customers, recent orders, low-stock alerts, 6-month bar+line chart (Swift Charts)
- 🏷️ **Categories** — Color-coded income categorization
- 📂 **Income list** — Search, filter by category, group by month

### Onboarding & Settings
- 🚀 **3-step onboarding wizard** — Welcome screen, industry picker (Café · Retail · Service · Empty), confirm with preview
- ⚙️ **Re-runnable wizard** — Restart from Settings any time without resetting data
- 🧹 **Reset all data** — Atomic wipe of products, customers, orders, deliveries, income (PIN and account preserved)
- 🔄 **Hub quick actions** — One-tap to New Order / New Customer / New Delivery from the home screen

### UX polish
- ↻ **Pull-to-refresh** on all list views
- ↔️ **Swipe actions** for delete on lists
- 📳 **Haptic feedback** on every primary action
- 💡 **Friendly empty states** with primary CTAs that resolve them
- ⌨️ **Keyboard toolbars** with Done buttons in all forms
- 🎯 **Long-press context menus** on products and deliveries

## Tech Stack

- SwiftUI + Combine (reactive MVVM, `@MainActor` view models)
- SQLite + SQLCipher (encrypted at rest, atomic transactions)
- iOS Keychain (encryption-key storage)
- LocalAuthentication (Face ID / Touch ID)
- CryptoKit + CommonCrypto (AES-256-GCM, PBKDF2-HMAC-SHA256)
- Swift Charts (analytics)
- **One** third-party dependency: SQLCipher.swift

## Project Structure

```
ShopVault/
├── ShopVault/            ← Core SPM library (security, theme, base models)
├── ShopVaultApp/         ← Xcode iOS app
│   └── ShopVaultApp/
│       ├── App/          ← @main entry, notifications
│       ├── Database/     ← DatabaseManager, schema, migrations, seed
│       ├── Models/       ← Domain models (Product, Order, Customer, …)
│       ├── Repositories/ ← DB-access layer
│       ├── ViewModels/   ← @MainActor ObservableObjects
│       ├── Views/        ← SwiftUI views
│       ├── Theme/        ← AppTheme, glass cards, gradients
│       ├── Security/     ← Encryption, PIN hashing, biometric, PII
│       └── Services/     ← Export service
├── ShopVaultMac/         ← Standalone macOS snapshot viewer (SPM)
│   ├── Sources/
│   ├── icon.svg          ← Source icon (mint S + lock badge)
│   ├── make-icon.sh      ← Generates AppIcon.icns from icon.svg
│   └── build-app.sh      ← Builds the .app bundle with codesign
├── ShopVaultTests/       ← Unit tests
└── docs/                 ← Architecture, security, setup notes
```

## Build

### iOS app

Requirements: Xcode 16+, iOS 17+

```bash
open ShopVaultApp/ShopVaultApp.xcodeproj
# Set your own Apple Team ID + Bundle Identifier in
# Signing & Capabilities for all 3 targets, then ⌘R
```

Or via CLI (Simulator):

```bash
xcodebuild -project ShopVaultApp/ShopVaultApp.xcodeproj \
           -scheme ShopVaultApp \
           -destination 'generic/platform=iOS Simulator' \
           build
```

> The empty `DEVELOPMENT_TEAM = "";` in `project.pbxproj` is intentional — every fork sets its own.

### macOS viewer

Requirements: macOS 14+

```bash
cd ShopVaultMac
./build-app.sh
open "./build/ShopVault Viewer.app"
# To install:  cp -R "./build/ShopVault Viewer.app" /Applications/
```

The script builds a proper `.app` bundle with icon, Info.plist, and ad-hoc signature. Designed to look and feel like a real Mac app — not a `swift run` shell.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                       SwiftUI Views                     │
│   (HubView, ShopView, InventoryView, OrdersListView,    │
│   CustomerListView, DeliveryListView, FinanceView, …)   │
└──────────────────────────┬──────────────────────────────┘
                           │ @StateObject / @Published
┌──────────────────────────▼──────────────────────────────┐
│                       ViewModels                        │
│           (@MainActor, ObservableObject)                │
└──────────────────────────┬──────────────────────────────┘
                           │ async/await
┌──────────────────────────▼──────────────────────────────┐
│                      Repositories                       │
│  ProductRepo · OrderRepo · CustomerRepo · IncomeRepo    │
│       · DeliveryRepo · CategoryRepo · SettingsRepo      │
└──────────────────────────┬──────────────────────────────┘
                           │ SQL (transactional)
┌──────────────────────────▼──────────────────────────────┐
│                    DatabaseManager                      │
│            SQLCipher (AES-256 encrypted)                │
└──────────────────────────┬──────────────────────────────┘
                           │
                       Keychain
                  (encryption keys)
```

### Database schema (v4)

| Table | Purpose |
|---|---|
| `users` | Single local user, PIN hash, biometric flag |
| `app_settings` | Auto-lock, currency, locale, **`onboarding_completed`** |
| `categories` | Income categories (color-tagged) |
| `income_entries` | All income (manual + auto-from-order) |
| `products` | Inventory: code, name, spec, price, stock, threshold, favorite, active |
| `customers` | CRM: name + encrypted phone/email/address |
| `orders` + `order_items` | Sales orders with line items, discount, link to income entry |
| `supplier_deliveries` + `delivery_items` | Inventory receipts with cost tracking |
| `schema_version` | Migration tracking (v1 → v4) |

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

The Mac viewer derives the AES key from the user-supplied passphrase using PBKDF2 (600k rounds, SHA-256), then decrypts the GCM-sealed payload. Decrypted data lives only in RAM — **nothing is ever written to disk by the viewer.**

PII (customer phone / email / address) is field-level encrypted in the iOS database and decrypted **inside** the encrypted export so the Mac viewer can show it without holding extra secrets.

## Roadmap

Open ideas — PRs welcome:

- [ ] Receipt sharing (PDF / image after order completion)
- [ ] Reports tab (P&L, customer cohorts, product velocity)
- [ ] Global search across orders/customers/products from the Hub
- [ ] CSV export from the Mac viewer
- [ ] Multi-currency per order (currently global)
- [ ] iCloud-encrypted backup option (passphrase-derived key, not iCloud account key)

## Contributing

PRs welcome! See [CONTRIBUTING.md](CONTRIBUTING.md). For security issues, please follow [SECURITY.md](SECURITY.md) instead of filing a public issue.

## License

MIT — see [LICENSE](LICENSE).
