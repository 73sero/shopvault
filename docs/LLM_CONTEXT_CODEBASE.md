# LLM Context: Codebase

## Projektstruktur

- Root: `/Users/sero/Desktop/ShopVault`
- Haupt-App (Source of Truth fuer aktuelle Arbeit): `ShopVaultApp/ShopVaultApp`
- Xcode-Projekt: `ShopVaultApp/ShopVaultApp.xcodeproj`
- Alternativer/duplizierter Pfad: `ShopVault/` (teilweise parallel gepflegt)

## Architektur

- UI: SwiftUI
- Pattern: MVVM + Repositories
- Datenzugriff: `Repositories/*`
- State: `Models/AppState.swift`
- Sicherheit: `Security/*`
- DB-Zugang: `Database/DatabaseManager.swift`

## App-Flow (vereinfacht)

1. App startet und laedt/erstellt User + Settings
2. Wenn kein PIN vorhanden: `requiresPINSetup = true`
3. Danach normaler Tab-Flow (Dashboard, Liste, Add, Settings)
4. Bei Lock: `AppLockView`

## PIN/Biometrie-Stand

- PIN-Setup ist in `ContentView.swift` integriert.
- PIN-Laengen aktuell: 4, 6, 8
- Eingabe wird auf numerisch + gewaehlte Laenge begrenzt
- Biometrie-Option im Setup vorhanden (Face ID/Touch ID, geraeteabhaengig)
- App-Lock respektiert `user.biometricEnabled`

## Relevante Dateien bei Auth/Security-Änderungen

- `ShopVaultApp/ShopVaultApp/ContentView.swift`
- `ShopVaultApp/ShopVaultApp/Views/AppLockView.swift`
- `ShopVaultApp/ShopVaultApp/ViewModels/AppLockViewModel.swift`
- `ShopVaultApp/ShopVaultApp/Security/BiometricAuth.swift`
- `ShopVaultApp/ShopVaultApp/Security/KeychainManager.swift`
- `ShopVaultApp/ShopVaultApp/Security/PinHashService.swift`

## Relevante Dateien bei Datenbank-Änderungen

- `ShopVaultApp/ShopVaultApp/Database/DatabaseManager.swift`
- `ShopVaultApp/ShopVaultApp/Database/schema.sql`

## Preview-Hinweis

- Viele Views haben aktive `#Preview`-Blöcke.
- Bei State-Mutationen in Preview immer Closure-Init verwenden, damit kein `Type '()' cannot conform to 'View'` entsteht.
