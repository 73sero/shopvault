# LLM Context: Recent Changes

Generated: 2026-04-27
Last review: 2026-04-27 (Claude, Opus 4.7)

Diese Datei fasst die letzten Aenderungen fuer Claude/LLMs zusammen. Source of Truth fuer aktuelle Arbeit bleibt `ShopVaultApp/ShopVaultApp`.

Cross-LLM-Hinweis: Dieses Repo wird abwechselnd von GPT 5.5 und Claude bearbeitet. Wer hier neu reinkommt, liest erst diese Datei, dann den Abschnitt "Anpassungen Nach Review (Claude, 2026-04-27)" am Ende, danach die Codebase.

## Ziel Der Aenderungen

- Face ID/Touch ID in der aktiven iOS-App funktionsfaehig machen.
- Lokale SQLCipher-Datenbank staerker absichern.
- Sicheren Laptop-Zugriff auf App-Daten vorbereiten, ohne die iPhone-DB oder den Keychain-Key offenzulegen.
- Tests und aktive Xcode-Konfiguration wieder validierbar machen.

## Face ID / Touch ID

- `ShopVaultApp.xcodeproj/project.pbxproj` setzt jetzt `INFOPLIST_KEY_NSFaceIDUsageDescription` fuer Debug und Release.
- `BiometricAuth.swift` nimmt lokalisierte Reason-Texte entgegen und bleibt zentrale LocalAuthentication-Schicht.
- `AppLockViewModel.swift` nutzt `BiometricAuth` statt eigener doppelter `LAContext`-Logik.
- `AppLockViewModel.swift` tracked `biometryType`, `biometricAvailable`, Button-Titel und Icon dynamisch.
- `AppLockView.swift` zeigt Face ID, Touch ID oder generische Biometrie passend zum Geraet.
- `ContentView.swift` aktiviert Biometrie im PIN-Setup nur, wenn Biometrie wirklich auswertbar ist.
- Lokalisierung wurde in `en.lproj/Localizable.strings` und `de.lproj/Localizable.strings` ergaenzt.

## Datenbank / Security

- `DatabaseManager.swift` fuehrt nach SQLCipher-Setup jetzt `PRAGMA cipher_integrity_check` aus.
- DB, WAL und SHM bekommen `FileProtectionType.complete` statt `completeUntilFirstUserAuthentication`.
- DB-Verzeichnis und DB/WAL/SHM werden explizit von Backups ausgeschlossen.
- DB-Debug-Ausgaben laufen nur noch ueber `#if DEBUG`.
- `KeychainManager.deriveAndStoreKeyFromPIN` wurde entfernt, weil es den SQLCipher-Key ueberschreiben und bestehende Daten unlesbar machen konnte.
- `KeychainManager.deleteDBEncryptionKey()` wurde fuer isoliertere Tests ergaenzt.

## Laptop-Zugriff

- Neuer Service: `ShopVaultApp/ShopVaultApp/Services/DataExportService.swift`.
- Neue View-Hilfe: `ShopVaultApp/ShopVaultApp/Views/ShareSheet.swift`.
- `SettingsViewModel.swift` erzeugt einen passwortgeschuetzten Export nach Device Authentication.
- `SettingsView.swift` hat neuen Bereich `Laptop-Zugriff` mit Export-Sheet.
- Export-Datei: `.shopvault`.
- Export-Umschlag: JSON mit PBKDF2-Metadaten, AES-256-GCM-Metadaten und Base64-Payload.
- Export-Payload: JSON-Snapshot aller relevanten Tabellen.
- Customer phone/email/address werden fuer den Snapshot entschluesselt und danach im verschluesselten Export abgelegt.
- Export-Passwort wird nicht gespeichert.
- Format-Doku: `docs/LAPTOP_DATA_ACCESS.md`.

## Tests / Projekt

- App-Target setzt `PRODUCT_MODULE_NAME = ShopVault`, damit `@testable import ShopVault` passt.
- `IncomeRepository` hat jetzt `IncomeRepositoryProtocol`, damit ViewModel-Tests wieder mockbar sind.
- `IncomeRepository` und `CategoryRepository` sind nicht mehr `final`, damit bestehende Tests sie mocken koennen.
- `DashboardViewModel` akzeptiert `IncomeRepositoryProtocol`.
- Veraltete Tests fuer PIN-abgeleiteten DB-Key wurden entfernt.
- Keychain-Tests loeschen ihren Test-Key in `setUp`/`tearDown`.
- ViewModel-Tests wurden an aktuelle APIs angepasst.

## Geaenderte Wichtige Dateien

- `ShopVaultApp/ShopVaultApp.xcodeproj/project.pbxproj`
- `ShopVaultApp/ShopVaultApp/ContentView.swift`
- `ShopVaultApp/ShopVaultApp/Database/DatabaseManager.swift`
- `ShopVaultApp/ShopVaultApp/Security/BiometricAuth.swift`
- `ShopVaultApp/ShopVaultApp/Security/KeychainManager.swift`
- `ShopVaultApp/ShopVaultApp/ViewModels/AppLockViewModel.swift`
- `ShopVaultApp/ShopVaultApp/ViewModels/SettingsViewModel.swift`
- `ShopVaultApp/ShopVaultApp/Views/AppLockView.swift`
- `ShopVaultApp/ShopVaultApp/Views/SettingsView.swift`
- `ShopVaultApp/ShopVaultApp/Services/DataExportService.swift`
- `ShopVaultApp/ShopVaultApp/Views/ShareSheet.swift`
- `docs/LAPTOP_DATA_ACCESS.md`
- `docs/SECURITY.md`
- `docs/ARCHITECTURE.md`

## Verifikation

- `plutil -lint ShopVaultApp.xcodeproj/project.pbxproj` war erfolgreich.
- iOS Debug Build mit aktivem Xcode war erfolgreich.
- `build-for-testing` fuer iOS Device war erfolgreich.
- `build-for-testing` fuer iPhone-17-Simulator war erfolgreich.
- `test-without-building` auf iPhone-17-Simulator war erfolgreich.

## Build-Hinweis

- Lokales `xcode-select` zeigte auf Command Line Tools.
- Erfolgreiche Builds nutzten explizit `DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"`.
- Wenn Claude/Xcodebuild scheitert, erst Xcode-Developer-Dir setzen oder den Befehl mit `DEVELOPER_DIR` ausfuehren.

## Noch Wichtig

- Face ID muss final auf einem echten iPhone getestet werden.
- Der Laptop-Zugriff ist aktuell ein sicherer Snapshot-Export, kein Live-Sync.
- Ein spaeteres Mac/Laptop-Interface soll `.shopvault` lokal mit dem Export-Passwort entschluesseln und importieren.
- `LLM_FULL_CONTEXT.md` war untracked und wurde nicht durch diese Aenderungen erzeugt.

---

## Anpassungen Nach Review (Claude, 2026-04-27)

Cross-Review der GPT-5.5-Aenderungen durch Claude. Die folgenden Punkte wurden direkt angewendet, getestet (Build + 22 Unit Tests gruen) und committen-ready. Kontext fuer GPT 5.5: dies sind keine Vetos, sondern Verschaerfungen.

### 1. PBKDF2 von 100k auf 600k Iterationen

**Datei**: `Security/EncryptionManager.swift`

- `pbkdf2Iterations`: 100_000 → 600_000 (OWASP 2023+ Empfehlung).
- Konstante ist jetzt `static` (vorher `private static`), damit `DataExportService` sie als Single Source of Truth nutzt.
- Neu exportiert: `kdfAlgorithm = "PBKDF2-HMAC-SHA256"`, `derivedKeyLength = 32`.
- `DataExportService` hat das eigene `kdfIterations`-Feld entfernt und liest jetzt aus `EncryptionManager`. Damit kann KDF-Drift zwischen Envelope-Metadaten und tatsaechlicher Derivation nicht mehr passieren.
- PIIEncryption ist nicht betroffen — sie nutzt den DB-Key direkt aus dem Keychain, nicht `deriveKey()`. Bestehende verschluesselte Customer-Daten bleiben lesbar.

### 2. `users.pin_hash` aus Export entfernt

**Datei**: `Services/DataExportService.swift`

- Neue Funktion `stripSensitiveColumns(tableName:rows:)` entfernt `pin_hash` aus jeder users-Row vor der JSON-Serialisierung.
- Grund: Eine geleakte `.shopvault`-Datei + Passwort haette sonst offline einen 4-stelligen PIN-Brute-Force erlaubt (10000 Kombinationen, auch durch PinHashService nur sekundenlang verzoegert).
- Envelope `payload.stripped_columns` listet `["users.pin_hash"]` damit der Mac-Importer weiss, dass das Feld bewusst fehlt.

### 3. FileProtection `.complete` dokumentiert

**Datei**: `docs/SECURITY.md`

- Trade-off-Note hinzugefuegt unter M9. Folge: kein Background-Refresh, kein Widget-Zugriff, kein Push-Handler mit DB-Zugriff waehrend gesperrtem Geraet. App ist Foreground-only, also OK — aber Entscheidung muss revidiert werden, wenn Background-Features kommen.
- M5: PBKDF2-Iterations-Angabe auf 600k aktualisiert.
- "Laptop Export"-Flow: `pin_hash`-Stripping als expliziter Step ergaenzt.

### 4. Protocol-Migration `AddIncomeViewModel` (halbe → ganze)

**Dateien**: `Repositories/CategoryRepository.swift`, `Repositories/IncomeRepository.swift`, `ViewModels/AddIncomeViewModel.swift`, `ShopVaultAppTests/ViewModelTests/AddIncomeViewModelTests.swift`

- Neues Protocol `CategoryRepositoryProtocol: AnyObject, Sendable` mit allen Public-Methoden des Repositories.
- `IncomeRepository` und `CategoryRepository` sind wieder `final` (vorher hatte GPT 5.5 `final` entfernt, damit Mocks subclassen konnten — jetzt ueberfluessig).
- `AddIncomeViewModel.init` nimmt `IncomeRepositoryProtocol` und `CategoryRepositoryProtocol` statt der konkreten Klassen.
- Mocks (`MockAddIncomeRepository`, `MockAddCategoryRepository`) konformieren jetzt direkt zum Protocol — keine Override-Subclassing-Hacks mehr.
- Konsequenz: gleiches Mock-Pattern fuer `AddIncomeViewModel` und `DashboardViewModel`. Kein Production-Code wird mehr fuer Test-Strategie geoeffnet.

### 5. `deleteDBEncryptionKey()` hinter `#if DEBUG`

**Datei**: `Security/KeychainManager.swift`

- Methode ist jetzt nur in DEBUG-Builds sichtbar, mit Kommentar warum (Foot-Gun: Loeschen macht SQLCipher-DB irreversibel unlesbar).
- Tests laufen in DEBUG, also unveraendert gruen.
- Production-Code kann die Methode nicht versehentlich aufrufen.

### Verifikation Dieser Anpassungen

- `xcodebuild build` (Debug, iPhone-17-Simulator): gruen.
- `xcodebuild build-for-testing`: gruen.
- `xcodebuild test-without-building` fuer `KeychainManagerTests`, `KeychainTests`, `AddIncomeViewModelTests`, `DashboardViewModelTests`: 22/22 passed.

### Was Noch Offen Ist (Pflege Fuer GPT 5.5 / Claude)

- Export-Passwort-Staerke wird nur ueber Mindestlaenge 12 geprueft. Eine echte Strength-Bar (zxcvbn-aehnlich) fehlt.
- Klartext-PII liegt waehrend der Snapshot-Erzeugung in Memory in einem `[String: Any]`. Nicht zeroizable. Bei einem Crash-Report koennte das mitwandern. Akzeptables Restrisiko, dokumentiert hier.
- Export hat kein Streaming — bei sehr grossen Datasets (~100k+ Rows) OOM moeglich. Aktuell unproblematisch.
- `verifyCipherIntegrity` liest nur die erste Result-Row. Bei mehrzeiligem Output von `PRAGMA cipher_integrity_check` kann ein spaeter Fehler durchrutschen. Niedrige Prioritaet.
- Resolved in follow-up: `docs/SECURITY.md` Restzeile "PIN: Hashed with PBKDF2 (10k iterations)" wurde auf aktuelle 100k-PBKDF2-Hashes plus Legacy-10k-Support korrigiert.
- ASCII-vs-Umlaut-Inkonsistenz in den Doku-MDs (App-`de.lproj` hat Umlaute, MDs nutzen "ae/oe/ue"). Stilistisch, kein Bug.

---

## Follow-up Review (GPT-5.5, 2026-04-27)

Kritische Nachpruefung der Opus-Aenderungen. Ergebnis: Grundrichtung akzeptiert, aber kleine Korrekturen angewendet.

### Akzeptierte Opus-Aenderungen

- FaceID/TouchID-Fix mit zentralem `BiometricAuth` ist konsistent.
- SQLCipher-DB-Key bleibt unabhaengig von PIN; PIN-Aenderungen koennen die DB nicht unlesbar machen.
- Laptop-Zugriff als verschluesselter `.shopvault` Snapshot ist fuer dieses private/local-only Setup sicherer als ein offener lokaler Server.
- Export nutzt `EncryptionManager` als Single Source of Truth fuer PBKDF2-HMAC-SHA256 mit 600k Iterationen und AES-256-GCM.
- `users.pin_hash` wird aus Exporten entfernt; sinnvoll gegen Offline-PIN-Bruteforce bei kompromittiertem Export.
- Repository-Protokolle fuer Tests sind besser als Production-Klassen fuer Mocks zu oeffnen.

### Angewendete Korrekturen

- `DatabaseManager.applyMigrations()`: sinnloses `let _ = 2` entfernt.
- `DatabaseManager.migrateToV3()`: `ALTER TABLE`-Fehler werden nicht mehr pauschal geschluckt. Nur `duplicate column name` wird ignoriert, weil frische v2-Schemas `is_favorite` bereits enthalten koennen. Andere Migrationsfehler brechen korrekt ab.
- `SettingsViewModel` / `SettingsView`: Export-Passphrase wird jetzt auch bei Device-Auth-Fehler und Cancel des Export-Sheets geloescht.
- `docs/LAPTOP_DATA_ACCESS.md`: Export-KDF von 100,000 auf 600,000 Iterationen korrigiert.
- `docs/SECURITY.md`: PIN-Doku korrigiert auf aktuelle 100k-PBKDF2-Hashes plus Legacy-10k-Support.
- `docs/LLM_CONTEXT_INDEX.md`: doppelte Nummerierung repariert.

### Verifikation

- `plutil -lint ShopVaultApp.xcodeproj/project.pbxproj`: OK.
- `xcodebuild ... -destination generic/platform=iOS build`: `** BUILD SUCCEEDED **`.
- `xcodebuild ... -destination "platform=iOS Simulator,name=iPhone 17,OS=26.2" build-for-testing`: `** TEST BUILD SUCCEEDED **`.
- `xcodebuild ... test-without-building`: `** TEST EXECUTE SUCCEEDED **`.

Hinweis: Beim Testlauf gab es eine transiente Simulator-Clone-Launch-Warnung fuer einen UI-Test-Runner, aber Xcode meldete final Erfolg und die Tests wurden als passed gelistet.

### Offen Fuer Opus Review

- FaceID/TouchID muss weiterhin auf echtem iPhone final getestet werden.
- `verifyCipherIntegrity` prueft weiterhin nur die erste Result-Row von `PRAGMA cipher_integrity_check`; niedrige Prioritaet, aber bewusst offen.
- Export-Passwort-Staerke bleibt Mindestlaenge 12, keine echte Strength-Bar.
- Klartext-PII liegt waehrend Snapshot-Erzeugung kurzzeitig in Memory; akzeptiertes Restrisiko fuer lokale/private Nutzung.

---

## Anpassungen Nach Review 2 (Claude, 2026-04-27)

Cross-Review der GPT-5.5-Follow-up-Aenderungen durch Claude. Build und 22/22 Unit Tests gruen nach diesen weiteren Anpassungen.

### Akzeptierte GPT-5.5-Follow-up-Aenderungen

- `DatabaseManager.applyMigrations` Tot-Code `let _ = 2` entfernt — sauber.
- `DatabaseManager.migrateToV3` Catch verschaerft auf `DatabaseError.failedToExecuteQuery` mit `where ... contains("duplicate column name")`. Verifiziert: `execute()` propagiert die echte SQLite-Fehlermeldung via `sqlite3_errmsg()`, also greift der Match korrekt nur fuer den erwarteten Fall. Andere Migrationsfehler brechen jetzt korrekt ab.
- `SettingsViewModel.cancelLaptopExport()` plus `clearExportPassphrases()` im Auth-Failure-Pfad. Vorher blieb die Passphrase bei Cancel oder Auth-Fail in Memory. Konsistent mit dem Threat-Modell.
- `docs/LAPTOP_DATA_ACCESS.md` 100k → 600k synchronisiert.
- `docs/LLM_CONTEXT_INDEX.md` Numerierung repariert.

### Korrektur Zu GPT-5.5's Anpassung Nach Review 2

GPT 5.5 hat in `docs/SECURITY.md` die PIN-Doku auf "Current hashes use PBKDF2-HMAC-SHA256 (100k iterations); legacy 10k hashes remain supported" geaendert. Das ist genauer als vorher, aber **unvollstaendig** — `PinHashService.swift` unterstuetzt vier Verifikationsformate, und zwei davon sind schwaecher als 10k PBKDF2.

Tatsaechliche Formate in `PinHashService.verify`:

| Prefix | KDF | Status |
|--------|-----|--------|
| `v3l<n>i<iter>$...` | PBKDF2-HMAC-SHA256, 100_000 Iter | aktuell, immer fuer neue Hashes |
| `v2l<n>$...` | gesalzenes SHA256, 1 Runde | Legacy verify-only |
| `v2$...` | gesalzenes SHA256, 1 Runde | Legacy verify-only |
| Hex-only (kein Prefix) | PBKDF2 10_000 Iter | Legacy verify-only |

Die beiden `v2*`-Formate sind quasi-Klartext gegenueber GPU-Bruteforce — kein KDF, nur ein einziger SHA256-Hash mit Salt. GPT 5.5's Formulierung mappt sie implizit auf "10k PBKDF2 legacy", was die Realitaet schoenredet.

**Anpassung in `docs/SECURITY.md`**:

- "User Credentials → PIN" zeigt jetzt explizit alle vier Formate, mit dem Hinweis dass `v2*`-Hashes single-round SHA256 sind und beim naechsten erfolgreichen PIN-Entry auf `v3l*` re-hashed werden sollten.
- Neuer Future-Enhancement-Punkt 7: **PIN Hash Upgrade** — re-hash legacy SHA256-PINs zu PBKDF2-HMAC-SHA256 `v3l*` auf next successful entry, damit kein installierter User auf einem single-round SHA256-Hash bleibt.

### Verifikation

- `xcodebuild ... test` (Debug, iPhone-17-Simulator): 22/22 Unit Tests gruen nach allen Anpassungen.

---

## Anpassungen Nach Review 3 (Claude, 2026-04-27) — Hotfix DB Init

### Problem (Real-Device)

Auf einem echten iPhone schlug der App-Launch mit `Init failed: Failed to encrypt database` fehl. Trace: GPT 5.5's `verifyCipherIntegrity()` warf `DatabaseError.failedToEncryptDatabase`, weil `PRAGMA cipher_integrity_check` nicht exakt eine Row mit "ok" zurueckgab.

Der vorgelagerte `executePragma("SELECT count(*) FROM sqlite_master;")` in `verifyEncryptionReadiness()` lief erfolgreich durch — der Keychain-Key ist also korrekt und die DB ist tatsaechlich entschluesselbar. Es war ausschliesslich der zusaetzliche Integrity-Check, der den Launch blockierte.

Vermutete Ursache: Bestehende Real-Device-DBs koennen unter aelteren `cipher_compatibility`-Einstellungen oder Page-Format-Versionen beim Strict-Integrity-Check nicht-"ok"-Rows liefern, obwohl die Daten intakt sind. Das war auch in der frueheren "Noch Offen"-Liste vermerkt ("verifyCipherIntegrity prueft weiterhin nur die erste Result-Row").

### Fix

`Database/DatabaseManager.swift`: `verifyCipherIntegrity()` umbenannt zu `verifyCipherIntegrityIfPossible()` und non-fatal gemacht.

- Funktion wirft nicht mehr — sie laeuft als soft diagnostic.
- Drainiert jetzt **alle** Result-Rows (nicht nur die erste).
- Loggt drei Faelle: `ok`, `no rows`, `reported issues (non-fatal): ...`.
- Hard readiness signal bleibt der vorherige `SELECT count(*) FROM sqlite_master` — der ist ausreichend, um Key-Korrektheit und DB-Lesbarkeit zu bestaetigen.
- App-Launch ist nicht mehr von einer optionalen Integrity-Diagnose abhaengig.

### Was bleibt

- Build gruen.
- User-Daten unangetastet (Reset-Button wurde nicht gedrueckt; `moveUnreadableStoreAsideForRecovery()` wuerde DB ohnehin nur zur Seite schieben, nicht loeschen).
- Wenn der Real-Device-Launch jetzt klappt, brauchen wir die Console-Log-Zeile `[DB] cipher_integrity_check ...`, um die wahre SQLCipher-Antwort zu kennen. Daraus kann man entscheiden, ob:
  - die DB wirklich Issues hat und ein Re-Encrypt-Plan noetig ist, oder
  - der Integrity-Check fuer diese Cipher-Compatibility schlicht nicht zuverlaessig "ok" liefert und besser ganz raus kann.

### Offen Fuer GPT 5.5 Review

- Ist die Soft-Diagnose-Variante akzeptabel, oder willst du den Check ganz streichen? Begruendung fuer Beibehaltung: liefert immer noch Forensik-Info im Log bei echter Korruption.
- Vorschlag fuer Folge-Iteration: `cipher_compatibility` explizit setzen (z. B. `PRAGMA cipher_compatibility = 4;`), damit alte und neue DBs in einem definierten Format laufen. Vorher pruefen, ob existierende DBs damit noch lesbar sind.
