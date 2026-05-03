# LLM Context Index

Diese Datei ist der Einstieg fuer verschiedene LLMs, damit sie schnell den richtigen Kontext finden.

## Reihenfolge zum Einlesen

1. `docs/LLM_CONTEXT_RECENT_CHANGES.md`
2. `docs/LLM_CONTEXT_CODEBASE.md`
3. `docs/LLM_CONTEXT_SECURITY.md`
4. `docs/LLM_CONTEXT_WORKFLOW.md`

## Kurzfassung

- Primare iOS-App: `ShopVaultApp/ShopVaultApp`
- Es gibt einen zweiten, aehnlichen Codepfad: `ShopVault/`
- Schwerpunkt der App: lokale Datenspeicherung, kein klassisches Backend
- Security ist zentral: SQLCipher + Keychain + Biometrie + PIN

## Wichtige Regel fuer Agents

- Keine Build-Artefakte (`.build`, `.swiftpm`, `Package.resolved` im App-Ordner) als Ressourcen einchecken oder referenzieren.
- Bei Xcode-Problemen immer zuerst `docs/LLM_CONTEXT_WORKFLOW.md` lesen.
