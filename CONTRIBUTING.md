# Contributing to ShopVault

Thanks for considering a contribution! ShopVault is a hobby-scale open-source project; we keep things simple and pragmatic.

## Ways to contribute

- 🐛 **Bug reports** — open a GitHub issue with reproduction steps and your iOS/macOS version
- 💡 **Feature requests** — open an issue to discuss before opening a PR
- 🔧 **Code** — fork, branch, PR
- 📖 **Docs** — typos, clarifications, architecture diagrams
- 🌍 **Translations** — add a new `*.lproj/Localizable.strings` file

## Pull Request Guidelines

- **Keep PRs small and focused** — one logical change per PR
- **Match the existing code style** — MVVM, `@MainActor` view models, repositories for DB access
- **Don't introduce third-party dependencies** without discussion (zero-deps is a feature)
- **Test what you change** — at minimum: Mac build (`swift build`) + iOS build (`xcodebuild ... build`)
- **Conventional commit messages** are appreciated: `fix:`, `feat:`, `docs:`, `refactor:`

## Build & Run

```bash
# iOS
open ShopVaultApp/ShopVaultApp.xcodeproj

# Mac viewer
cd ShopVaultMac && ./build-app.sh && open "./build/ShopVault Viewer.app"
```

## Security-Sensitive Changes

Anything touching:
- `Security/` (encryption, keychain, PIN hashing, biometrics)
- `DataExportService.swift`
- `DatabaseManager.swift` (especially encryption pragmas)

…requires extra review. Please flag these PRs explicitly. For vulnerability reports, use private disclosure (see [SECURITY.md](SECURITY.md)).

## Code of Conduct

This project adheres to the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating, you agree to abide by its terms.

## License

By contributing, you agree that your contributions will be licensed under the MIT License (see [LICENSE](LICENSE)).
