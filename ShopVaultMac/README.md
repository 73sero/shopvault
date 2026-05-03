# ShopVault Mac Viewer

Read-only Mac-Viewer für `.shopvault` Snapshots, die in der iPhone-App via **Settings → Laptop-Zugriff** erzeugt werden.

## Architektur

- Eigenständiges Swift Package, kein Coupling zur iOS-Codebasis.
- Liest und entschlüsselt nur `.shopvault` Dateien.
- Kein Schreibzugriff zurück zur iPhone-DB. Keine SQLCipher-Abhängigkeit.
- Decryption: AES-256-GCM mit PBKDF2-HMAC-SHA256 (600.000 Iterationen), exakt wie der Encrypt-Pfad in `ShopVaultApp/ShopVaultApp/Services/DataExportService.swift`.

## Workflow

1. iPhone: ShopVault öffnen → Settings → Laptop-Zugriff → Verschlüsselt exportieren → Passwort wählen → Face ID / PIN bestätigen.
2. Erzeugte `.shopvault` Datei via AirDrop / Files / iCloud auf den Mac übertragen.
3. Mac-Viewer starten (siehe unten).
4. Datei wählen → Export-Passwort eingeben → Entschlüsseln.
5. In der Sidebar Tabellen anklicken (income_entries, customers, products, …) und Daten browsen.

## Build & Run

In Xcode (empfohlen):

```bash
open ShopVaultMac/Package.swift
```

Dann in Xcode auf Run drücken.

Per Kommandozeile:

```bash
cd ShopVaultMac
swift run ShopVaultMac
```

> Mindestens macOS 14, weil `TableColumnForEach` für dynamische Spalten genutzt wird.

## Was die Sidebar zeigt

- Pro Tabelle: Name, Icon und Row-Count.
- Im unteren Abschnitt: Hinweise auf entfernte Spalten, z. B. `users.pin_hash` (wird bewusst nicht exportiert, damit ein geleakter Snapshot keinen offline PIN-Bruteforce erlaubt).

## Was passiert lokal

- Datei wird in Memory entschlüsselt.
- PBKDF2 läuft auf einem Background-Thread (1–2 s auf modernem Mac).
- Daten verlassen den Mac nicht. Es gibt keinen Netzwerk-Code.

## Was der Viewer (noch) nicht kann

- Schreiben zurück zur iPhone-DB (außerhalb des Scope der `.shopvault`-Architektur).
- Diff zwischen mehreren Exports.
- CSV/Excel-Export.
- Persistenter Cache der entschlüsselten Daten (jede Session = neu öffnen + entschlüsseln).
