# LLM Context: Security

## Sicherheitsmodell

- Kein Remote-Backend, Daten liegen lokal auf dem Geraet.
- Schutzschichten:
  - SQLCipher fuer Datenbankverschluesselung
  - Keychain fuer Schluesselmaterial
  - Biometrie + PIN fuer App-Unlock
  - Dateischutz/Backup-Exclusion fuer DB-Dateien
  - Verschluesselter `.shopvault` fuer Laptop-Zugriff

## SQLCipher-Setup

- Xcode-Package fuer SQLCipher ist im `.xcodeproj` hinterlegt.
- Runtime-Code nutzt bedingten Import (`canImport(SQLCipher)`) in `DatabaseManager.swift`.
- Security-Pruefungen laufen ueber SQLCipher-spezifische PRAGMAs.

## Wichtige harte Regeln

- Keine Rueckkehr zu plain SQLite ohne explizite Freigabe.
- Keine Secrets in Repo-Dateien einchecken.
- Keychain-Daten nur mit passenden Accessibility-Flags speichern.
- PIN nur numerisch verarbeiten.

## PIN-Stand

- Gehashte PIN via `PinHashService` (versioniertes Format)
- Unterstuetzte PIN-Laengen: 4/6/8
- Lockout-Backoff bei Fehlversuchen in `AppLockViewModel`
- PIN darf den SQLCipher-Key nicht ableiten oder ueberschreiben.

## Laptop-Zugriff

- Export laeuft ueber `Settings -> Laptop-Zugriff`.
- Export-Datei ist AES-256-GCM-verschluesselt und passwortbasiert.
- Format ist in `docs/LAPTOP_DATA_ACCESS.md` dokumentiert.

## Lokalisierung bei Security/UI-Texten

- EN: `ShopVaultApp/ShopVaultApp/en.lproj/Localizable.strings`
- DE: `ShopVaultApp/ShopVaultApp/de.lproj/Localizable.strings`

## Wenn Security-Code angepasst wird

- Immer Auth-Flow pruefen:
  - Setup-PIN
  - Unlock mit PIN
  - Unlock mit Biometrie
  - Reset-PIN via Device-Auth
- Bei Änderungen an Verschluesselung auch First-Run und Upgrade-Szenarien testen.
