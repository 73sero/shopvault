# LLM Context: Build & Workflow

## Typische Kommandos

- Projektdatei pruefen:
  - `plutil -lint "ShopVaultApp/ShopVaultApp.xcodeproj/project.pbxproj"`
- Package im Root bauen:
  - `swift build`

## Xcode-Fehlerbild: Duplicate Outputs

Wenn Dateien aus `.build/index-build/...` oder `.build/repositories/...` als App-Resource auftauchen:

1. Xcode schliessen
2. Loeschen:
   - `ShopVaultApp/ShopVaultApp/.build`
   - `ShopVaultApp/ShopVaultApp/.swiftpm`
   - `~/Library/Developer/Xcode/DerivedData/ShopVaultApp-*`
3. Xcode oeffnen
4. `File -> Packages -> Reset Package Caches`
5. `File -> Packages -> Resolve Package Versions`
6. `Product -> Clean Build Folder`

## Xcode-Fehlerbild: Missing package product

- Prüfen, dass SQLCipher als Package im `.xcodeproj` verknüpft ist.
- Sicherstellen, dass nicht parallel ein lokaler App-Ordner-`Package.swift` dieselbe Binary nochmals indirekt einbindet.

## Simulator/Preview Hinweise

- Mehrere Simulatoren kommen oft von Test-Run statt normalem Run.
- Fuer Face-ID-UI-Tests im Simulator:
  - passendes iPhone-Modell waehlen
  - `Features -> Face ID -> Enrolled`

## Preview-Regeln

- Preview-State per Closure erzeugen:
  - `let appState: AppState = { ...; return state }()`
- In `#Preview` keine losen Zuweisungen als einzelne Builder-Statements stehen lassen.

## Empfehlung fuer Agents

- Erst lesen, dann aendern, dann minimal verifizieren.
- Bei gleichzeitig vorhandenen Pfaden (`ShopVaultApp/...` und `ShopVault/...`) klar dokumentieren, welcher Pfad geaendert wurde.
