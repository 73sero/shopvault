# ShopVault Architecture

## Overview

ShopVault is a privacy-first iOS income tracking app built with **SwiftUI**, **MVVM**, and **SQLCipher encryption**.

```
┌─────────────────────────────────────────────────┐
│         ShopVaultApp (Entry Point)            │
│              + AppState (Observable)            │
└────────────────┬────────────────────────────────┘
                 │
        ┌────────▼─────────┐
        │   ContentView    │
        │  (TabView Router)│
        └────────┬─────────┘
                 │
    ┌────────────┼────────────┬──────────────┐
    │            │            │              │
    ▼            ▼            ▼              ▼
Dashboard  IncomeList  AddIncome       Settings
    │            │            │              │
    └────────────┼────────────┴──────────────┘
                 │
        ┌────────▼──────────────┐
        │    ViewModels         │
        │  (State Management)   │
        └────────┬──────────────┘
                 │
    ┌────────────┼────────────┬──────────────┐
    │            │            │              │
    ▼            ▼            ▼              ▼
Repositories  Database    Security       Models
(Data Access) (SQLCipher) (Keychain)   (Entities)
```

## Layers

### 1. **Models** (`Models/`)
- `IncomeEntry` — Income data with amount, source, category, date
- `Category` — Income categories with color coding
- `User` — User profile with biometric/PIN settings
- `AppState` — Global reactive state (authentication, lock status)

### 2. **ViewModels** (`ViewModels/`)
MVVM pattern with async/await + Combine:
- `AppLockViewModel` — Biometric auth, PIN entry, key derivation
- `IncomeListViewModel` — List, search, filter, delete operations
- `AddIncomeViewModel` — Form validation, category selection, save
- `DashboardViewModel` — Weekly/monthly totals, category breakdown
- `SettingsViewModel` — Auto-lock, logout

### 3. **Views** (`Views/`)
SwiftUI components:
- `AppLockView` — Biometric prompt + PIN entry sheet
- `DashboardView` — Summary cards, recent entries
- `IncomeListView` — Searchable list with swipe-to-delete
- `AddIncomeView` — Form with date picker, category selector
- `SettingsView` — App settings, logout button
- `ContentView` — Main TabView (4 tabs)
- `ShopVaultApp` — Root app entry, database initialization

### 4. **Repositories** (`Repositories/`)
Data access abstraction:
- `UserRepository` — CRUD user operations
- `CategoryRepository` — CRUD categories, defaults
- `IncomeRepository` — CRUD income entries, queries

### 5. **Database** (`Database/`)
SQLite with SQLCipher:
- `DatabaseManager` — SQLCipher wrapper, encryption key management
- `schema.sql` — DDL with 4 core tables + indexes + constraints
- **Encryption**: PRAGMA key applied on connection
- **Migrations**: Schema versioning system

### 6. **Security** (`Security/`)
Cryptography + authentication:
- `KeychainManager` — Store/retrieve DB encryption key, PIN hashing (PBKDF2)
- `BiometricAuth` — FaceID/TouchID authentication with LAContext
- `EncryptionManager` — AES-256-GCM encrypt/decrypt, key derivation

## Data Flow

### Authentication Flow
```
1. App opens → AppState.isLocked = true
2. AppLockView shown
3. User taps biometric → BiometricAuth.authenticate()
4. Success → AppState.handleAuthentication() → isLocked = false
5. ContentView shows the app UI

Database initialization currently happens during app startup using SQLCipher and the Keychain-stored database key. The lock screen gates UI access; it does not derive or replace the database key.
```

### Add Income Flow
```
1. User taps "Add" tab
2. AddIncomeView sheet opens
3. User fills form → AddIncomeViewModel validates
4. User taps Save → repository.saveEntry()
5. IncomeRepository.saveEntry() → DatabaseManager.execute(INSERT SQL)
6. Database encrypts data transparently (SQLCipher)
7. Success → sheet closes, list refreshes
```

### Auto-Lock Flow
```
1. User authenticates → AppState.startAutoLockTimer() (5 min)
2. User navigates app
3. Timer fires → AppState.isLocked = true
4. AppLockView shown again
5. User must re-authenticate
```

## State Management

**AppState** (root, @StateObject):
- `isAuthenticated` — User logged in
- `isLocked` — Requires biometric/PIN
- `currentUser` — Current User
- `categories` — User's categories
- `lastLockTime` — For timeout tracking

**ViewModels**:
- Each tab has its own ViewModel (@StateObject)
- @Published properties for reactive updates
- Combine Publishers for debouncing (search)
- async/await for async operations

## Security Considerations

See `SECURITY.md` for complete threat model.

**Key Points:**
- ✅ Encryption: SQLCipher database encryption
- ✅ Export: password-protected `.shopvault` snapshots for laptop access
- ✅ Key Storage: iOS Keychain (whenUnlockedThisDeviceOnly)
- ✅ Authentication: FaceID/TouchID + PIN fallback
- ✅ Auto-Lock: 5-minute timeout
- ✅ Backup Exclusion: DB excluded from iCloud/iTunes
- ✅ Memory: No plaintext financial data in memory (cleared on lock)

## Testing

- **Unit Tests**: ViewModels, Security (Keychain, Encryption)
- **Integration Tests**: Database CRUD, repository queries
- **Security Tests**: Key derivation, encryption/decryption
- **Mocks**: Mock repositories for isolated testing

## Dependencies

Minimal external dependencies:
- **SQLCipher** (SPM) — Transparent database encryption
- **LocalAuthentication** (iOS built-in) — Biometric auth
- **CryptoKit** (iOS built-in) — AES-256-GCM
- **CommonCrypto** (iOS built-in) — PBKDF2

No backend APIs. Everything local.

## Build Configuration

### Schemes
- **Debug**: Full logging, test fixtures
- **Release**: Optimizations, analytics
- **TestFlight**: Release + beta testing

### Targets
- **ShopVault** (main app)
- **ShopVaultTests** (unit + security tests)

## Future Enhancements

- **v2**: Orders linkage, charts, advanced filters
- **v3**: CSV export, encrypted backup/restore
- **v4**: iCloud encrypted sync (proposal only)

---

See `SETUP.md` for build instructions.
