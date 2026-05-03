# ShopVault Mac Viewer

Read-only macOS app for browsing `.shopvault` snapshots exported from the iPhone app via **Settings → Laptop access → Encrypted export**.

## Architecture

- Standalone Swift Package — no coupling to the iOS codebase.
- Reads and decrypts `.shopvault` files only. Never writes back.
- No SQLCipher dependency. No third-party dependencies at all.
- Decryption: AES-256-GCM with PBKDF2-HMAC-SHA256 (600 000 iterations) — identical to the encrypt path in `ShopVaultApp/ShopVaultApp/Services/DataExportService.swift`.
- Decrypted data lives only in memory; closing the app discards everything.

## What you get

A native macOS app with **6 sections**:

| Section | Content |
|---|---|
| **Shop overview** | Stat tiles (revenue, profit, margin, customers, products, cost), 6-month bar+line chart (revenue vs. cost vs. profit), top customers, recent orders, low-stock alerts |
| **Orders** | Filterable list + master/detail with full line items, discount, customer contact info |
| **Customers** | Sorted by lifetime spend; per-customer order history, contact pills (selectable text), notes |
| **Products** | Card grid with code badge, spec pill, stock-fill bar, filter chips (All / Low / Empty / Favorites / Hidden) |
| **Income overview** | Stats + monthly bar chart + category donut chart with breakdown legend, filterable list |
| **Deliveries** | List with master/detail, items, cost; **right-click → Hide** to filter out old / erroneous deliveries locally (persists in macOS UserDefaults; the snapshot file stays untouched) |

The dashboards exclude hidden deliveries from totals so profit and margin numbers reflect what you want to see.

## Workflow

1. iPhone: Open ShopVault → Settings → "Laptop access" → "Encrypted export" → choose password → confirm with Face ID / PIN
2. Transfer the `.shopvault` file to your Mac via AirDrop / Files / iCloud Drive / email
3. Open the Mac viewer (see Build below)
4. Pick the file → enter the export password → Unlock
5. Browse the 6 sections from the sidebar

## Build & Run

### Recommended: native `.app` bundle

The build script produces a real `.app` with icon and Info.plist (necessary so file pickers work and the window grabs keyboard focus):

```bash
cd ShopVaultMac
./build-app.sh
open "./build/ShopVault Viewer.app"
# Install permanently:
cp -R "./build/ShopVault Viewer.app" /Applications/
```

### Quick dev loop

For iteration during development you can use plain SPM, but file pickers may misbehave:

```bash
cd ShopVaultMac
swift run ShopVaultMac
```

> Requires macOS 14+ (uses `TableColumnForEach`, `@Observable`, `Charts.SectorMark`).

### Regenerating the app icon

If you tweak `icon.svg`:

```bash
./make-icon.sh   # rebuilds AppIcon.icns from icon.svg
./build-app.sh   # picks up the new icon
```

## Privacy guarantees

- The viewer has **no network code.** Run it offline if you want.
- The chosen password is held only in memory for the decryption call, then cleared.
- Decrypted data lives only in `@Observable` view state — quitting the app removes it from RAM.
- Hidden deliveries are stored as **delivery IDs only** (no content) in `UserDefaults` — does not leak data.

## What the viewer doesn't do (by design)

- Write back to the iPhone database — that would defeat the snapshot model and break the export signature.
- Diff between multiple exports.
- CSV / Excel export (open issue if you need this).
- Persist decrypted data — every session re-prompts for the password. This is a feature.
