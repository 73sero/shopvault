# ShopVault Setup & Build Guide

## Requirements

- **Xcode** 15.0+
- **Swift** 5.9+
- **iOS Deployment Target** 15.0+
- **Mac OS** 13.0+ (for building)

## Installation

### 1. Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/shopvault.git
cd shopvault
```

### 2. Install Dependencies (SPM)

Swift Package Manager is integrated. No `pod install` needed.

```bash
# Dependencies are automatically resolved on build
# (or manually trigger via Xcode)
```

### 3. Open in Xcode

```bash
open ShopVault.xcodeproj
```

Or open `ShopVault.xcworkspace` if using CocoaPods (optional fallback).

### 4. Configure Signing

In Xcode:
1. Select **ShopVault** target
2. Go to **Signing & Capabilities**
3. Set **Team** to your Apple Developer account
4. Set **Bundle Identifier** to `com.shopvault.tracker` (or your custom ID)

### 5. Build & Run

#### Debug Build (Simulator)
```bash
xcodebuild build -scheme ShopVault -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15'
```

#### Debug Build (Device)
```bash
xcodebuild build -scheme ShopVault -configuration Debug -destination 'platform=iOS,name=<your-device-name>'
```

#### Release Build (TestFlight)
```bash
xcodebuild build -scheme ShopVault -configuration Release -destination 'platform=iOS,name=<your-device-name>'
```

Or via Xcode:
1. Select **ShopVault** scheme
2. Select target device
3. Press **⌘R** to build and run

### 6. Run Tests

```bash
# All tests
xcodebuild test -scheme ShopVault

# Specific test class
xcodebuild test -scheme ShopVault -testNameSubstring AddIncomeViewModelTests

# With code coverage
xcodebuild test -enableCodeCoverage YES
```

Or in Xcode:
1. Press **⌘U** to run all tests
2. View test results in **Test Navigator**

---

## Environment Configuration

### .env File (Optional)

Copy `.env.example` to `.env` (local, not versioned):

```bash
cp .env.example .env
```

Edit `.env` with your values (secrets, build numbers, etc.):

```
BUILD_NUMBER=1
VERSION=1.0.0
LOG_LEVEL=debug
```

**Note**: `.env` is in `.gitignore`. Keep it local.

---

## First Run Walkthrough

1. **App Opens** → AppState initializes
2. **Database Opens** → SQLCipher creates encrypted DB
3. **Default User Created** → Automatic on first launch
4. **Default Categories** → Freelance, Passive Income, Salary, Other
5. **AppLockView Shows** → Ready for biometric/PIN setup
6. **Authentication** → Tap FaceID or PIN button
7. **Dashboard** → See empty state initially
8. **Add Income** → Tap "Add" tab to create entry
9. **View List** → Income entries appear in "Income" tab
10. **Settings** → Customize auto-lock timeout, logout

---

## Development Workflow

### Branch Strategy (Gitflow)

```bash
# Create feature branch
git checkout -b feature/add-charts

# Work on feature
git add ShopVault/Views/ChartView.swift
git commit -m "feat: add chart view with sample data"

# Push and create PR
git push origin feature/add-charts

# After approval, merge to main
git checkout main
git merge --no-ff feature/add-charts
```

### Conventional Commits

Format: `<type>: <description>`

Types:
- `feat:` new feature
- `fix:` bug fix
- `docs:` documentation
- `style:` code style (no logic change)
- `refactor:` refactor (no feature change)
- `test:` test addition/update
- `chore:` build, dependencies

Examples:
```bash
git commit -m "feat: add category filters to income list"
git commit -m "fix: resolve memory leak in database manager"
git commit -m "docs: update security checklist"
```

---

## Architecture

See `ARCHITECTURE.md` for detailed system design.

**Quick Overview**:
- **Models** — Data structures
- **ViewModels** — MVVM state management
- **Views** — SwiftUI UI components
- **Repositories** — Data access layer
- **Database** — SQLCipher encryption + schema
- **Security** — Keychain, Biometric, Encryption

---

## Security

See `SECURITY.md` for threat model and mitigations.

**Key Points**:
- ✅ AES-256-GCM encryption (SQLCipher)
- ✅ Keychain key storage (not hardcoded)
- ✅ FaceID/TouchID + PIN fallback
- ✅ Auto-lock on 5-minute timeout
- ✅ Database excluded from iCloud backup

---

## Testing

### Unit Tests

```bash
# Run all tests
xcodebuild test -scheme ShopVault

# Specific suite
xcodebuild test -scheme ShopVault -testNameSubstring KeychainManagerTests
```

### Test Structure

- `ViewModelTests/` — ViewModel logic, validation
- `DatabaseTests/` — CRUD operations, queries
- `SecurityTests/` — Keychain, Encryption, Biometric

### Code Coverage

```bash
xcodebuild test -enableCodeCoverage YES
# Results: Xcode > Reports > Code Coverage
```

Target: **80%+ coverage** for critical paths.

---

## Troubleshooting

### Build Fails
```
error: 'SQLCipher' target not found
```
**Solution**: Clean derived data:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
xcodebuild clean -scheme ShopVault
```

### Biometric Not Available
```
Biometric authentication is not available on this device
```
**Solution**: Only available on:
- iPhone with Face ID / Touch ID
- Simulator with `Biometric Simulation` enabled

### Database Locked
```
Error: database is locked
```
**Solution**: Database might be open in another context. Restart app.

### Tests Fail
```
XCTest failure: Keychain operation failed
```
**Solution**: Run on device or simulator with Keychain support. Clean and rebuild.

---

## Deployment

### TestFlight (Beta)

```bash
# Create Release build
xcodebuild build -scheme ShopVault -configuration Release

# Archive
xcodebuild archive -scheme ShopVault -archivePath "~/ShopVault.xcarchive"

# Validate
xcrun altool --validate-app -f ~/ShopVault.xcarchive -t ios -u <apple-id> -p <app-password>

# Upload
xcrun altool --upload-app -f ~/ShopVault.xcarchive -t ios -u <apple-id> -p <app-password>
```

Or via Xcode:
1. Select **ShopVault** scheme
2. Select **Release** configuration
3. Product → Archive
4. Organizer → Validate / Upload to TestFlight

### App Store

Same as TestFlight, but:
1. Ensure all tests pass ✅
2. Complete security checklist ✅
3. Add release notes
4. Submit for review

---

## Support

- **Issues**: GitHub Issues
- **Security**: docs/SECURITY.md
- **Architecture**: docs/ARCHITECTURE.md
- **Code**: Comments + type signatures

---

## License

Private. All rights reserved © 2026 Sero.
