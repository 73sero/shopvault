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
- **Don't introduce third-party dependencies** without discussion (one dep is the rule: SQLCipher)
- **Test what you change** — at minimum: Mac build (`swift build`) + iOS build (`xcodebuild ... build`)
- **Conventional commit messages** are appreciated: `fix:`, `feat:`, `docs:`, `refactor:`

## Code conventions

- **Theme tokens** — use `Color.App`, `Font.App`, `AppSpacing`, `AppRadius`, `LinearGradient.appAccent`. Don't inline hex colors or magic numbers.
- **Glass cards** — use the `.glassCard()` modifier instead of rolling your own background.
- **Empty states** — use the reusable `EmptyStateCard` component (see `Views/EmptyStateCard.swift`).
- **Forms** — use `ProductFormView` as the pattern: keyboard toolbar Done button, focused-state field navigation, inline validation, single GradientButton at the bottom.
- **Haptics** — call `HapticManager.impact(.light)` for taps, `.notification(.success/.error/.warning)` for outcomes.
- **DB writes** — wrap multi-statement operations in `databaseManager.transaction { ... }` and prefer `defer_foreign_keys` over disabling FK checks.
- **Stock changes** — clamp at 0 (use `CASE WHEN stock - ? < 0 THEN 0 ELSE stock - ? END`) so deletes don't go negative.

## Adding a new feature view

1. Create the `Models/X.swift` and the `Repositories/XRepository.swift`.
2. Create a `ViewModels/XViewModel.swift` (`@MainActor`, `ObservableObject`).
3. Create the `Views/XView.swift` and any sheets it needs.
4. Wire it into the routing — typically `ShopView`'s `navigationDestination`, or `HubView` for top-level access.
5. Post relevant `Notification.Name` (defined in `App/AppNotifications.swift`) so other views can refresh.
6. Verify both builds pass.

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
