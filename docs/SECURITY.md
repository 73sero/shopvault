# ShopVault Security

## Threat Model (OWASP Mobile Top 10)

### M1: Improper Authentication
**Risk**: Unauthorized access to financial data

**Mitigations**:
- ✅ FaceID/TouchID unlock when enabled and enrolled
- ✅ PIN fallback (4/6/8 digits, PBKDF2 hashed)
- ✅ Auto-lock on 5-minute inactivity
- ✅ No hardcoded credentials

### M2: Insecure Storage
**Risk**: Plaintext financial data on disk

**Mitigations**:
- ✅ SQLCipher AES-256 database encryption
- ✅ Database key in iOS Keychain (not hardcoded)
- ✅ Encryption key excluded from iCloud/iTunes backup
- ✅ Encrypted laptop export instead of exposing DB/key material
- ✅ NSUserDefaults not used for sensitive data

### M3: Insecure Communication
**Risk**: Data leakage over network (not applicable — local only)

**Status**: ✅ No network traffic. Offline-first design.

### M4: Insecure Data Logging
**Risk**: Sensitive data in logs

**Mitigations**:
- ✅ Debug logs only in Debug builds
- ✅ Financial data never logged
- ✅ Encryption keys never logged

### M5: Insufficient Cryptography
**Risk**: Weak encryption

**Mitigations**:
- ✅ SQLCipher for full database encryption
- ✅ AES-256-GCM for field-level PII and encrypted exports
- ✅ PBKDF2-HMAC-SHA256 key derivation (600,000 iterations, OWASP 2023+)
- ✅ Hardware-backed Keychain on Secure Enclave devices

### M6: Weak Server-Side Controls
**Status**: N/A (no backend)

### M7: Reverse Engineering & Tampering
**Risk**: App modification, jailbreak exploitation

**Mitigations**:
- ✅ Code obfuscation (via App Store)
- ✅ Jailbreak detection (optional, future)
- ✅ Runtime integrity checks (future)

### M8: Extraneous Functionality
**Status**: ✅ No debug APIs, no backdoors

### M9: Insecure Data Storage (App Backup)
**Risk**: DB leaked via iCloud/iTunes backup

**Mitigations**:
- ✅ Database file: `.complete`
- ✅ Keychain: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- ✅ Explicit backup exclusion via file attributes

> **Trade-off note**: `.complete` makes DB/WAL/SHM unreadable while the device is locked. This blocks any future Background Refresh, Widget, Push handler, or Shortcuts intent that would need DB access while locked. ShopVault is a foreground-only app, so this is acceptable. Revisit if background features are added — `.completeUntilFirstUserAuthentication` is the looser fallback.

### M10: Extraneous Functionality (Copy/Paste)
**Risk**: Financial data in pasteboard

**Mitigations**:
- ✅ No copy/paste for sensitive fields (future enhancement)
- ✅ Pasteboard cleared on app background (future)

---

## Encryption Strategy

### Encryption at Rest
```
Random 32-byte database key
    ↓ [Stored in iOS Keychain, ThisDeviceOnly]
    ↓ [Retrieved while device is unlocked]
SQLCipher: PRAGMA key = "x'...(hex key)...'"
    ↓ [SQLCipher database encryption]
    ↓
Encrypted Database on Disk
```

### Keychain Configuration
- **Item**: `com.shopvault.db.encryption.key` (32 bytes)
- **Accessibility**: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
  - Not accessible in background
  - Not backed up to iCloud/iTunes
  - Requires device lock (passcode/biometric)
- **Secure Enclave**: Hardware-backed on Face/Touch ID devices

### Database Protection
```swift
// On app launch
try DatabaseManager.shared.open()

// Inside: retrieves key from Keychain
// Applies: PRAGMA key = "x'<key_hex>'"

// SQLCipher handles transparent encryption/decryption
```

---

## Authentication Flow

### Initial Setup
```
1. App launches → check for encryption key in Keychain
2. No key? → Generate random 32-byte key → Store in Keychain
3. Create default User + Categories
```

### Daily Use (Locked State)
```
1. AppLockView shown
2. User taps biometric
3. BiometricAuth.authenticate() → LAContext.evaluatePolicy(.biometrics)
4. OS performs FaceID/TouchID check
5. Success? → Unlock app UI and load user state
6. Fail? → Show error, allow PIN fallback
```

### PIN Fallback
```
1. User taps "Use PIN" → PINEntryView
2. User enters 6-digit PIN
3. Hash with PBKDF2(pin, random_salt, 100k iterations)
4. Compare to stored pin_hash
5. Match? → Unlock app UI
6. No match? → Show error, retry (3 attempts then cooldown)
```

The PIN does not derive or replace the SQLCipher database key. This avoids making existing encrypted databases unreadable when the PIN changes.

### Laptop Export
```
1. User opens Settings → Laptop Access
2. User chooses an export password (not stored)
3. Device authentication confirms export intent
4. App builds a JSON data snapshot
5. Customer phone/email/address are decrypted inside the snapshot
6. `users.pin_hash` is stripped before serialization to prevent offline PIN brute-force from a leaked export
7. Snapshot is encrypted with AES-256-GCM using PBKDF2-HMAC-SHA256 (600,000 iterations)
8. App shares a `.shopvault` file for local Mac import
```

### Auto-Lock
```
1. After authentication → startAutoLockTimer(300 seconds)
2. User navigates tabs (doesn't reset timer in MVP)
3. Timer fires → isLocked = true
4. AppLockView appears
5. Requires re-authentication
```

---

## Data Security

### Income Entry Data
- **At Rest**: Encrypted via SQLCipher
- **In Memory**: Loaded into Swift models, cleared on lock
- **In Transit**: N/A (local only)

### Keychain Entry (Encryption Key)
- **Access Level**: Device unlock only
- **Backup**: Excluded from iCloud/iTunes
- **Biometric**: Can optionally require re-auth on every access (disabled for UX)

### User Credentials
- **Password**: Not stored (not applicable for local-only app)
- **PIN**: Current hashes use PBKDF2-HMAC-SHA256 (100,000 iterations) in versioned format `v3l<length>i<iterations>$<salt>$<hash>`. Legacy formats remain accepted **for verification only**: PBKDF2-10k (hex-only blob), salted SHA256 single-round (`v2l<length>$...`, `v2$...`). New hashes always use v3. The two `v2*` formats are weak against GPU brute-force and should be re-hashed to v3 on the next successful PIN entry (see Future Enhancements).
- **Biometric**: Handled by OS (not stored by app)

---

## Threat Mitigations

| Threat | Likelihood | Impact | Mitigation | Status |
|--------|-----------|--------|-----------|--------|
| Brute force attack on PIN | High | Medium | 3-attempt lockout + exponential backoff | ✅ |
| Keychain extraction (jailbreak) | Low | Critical | Jailbreak detection, key rotation | ⏳ TODO |
| Side-channel attack (timing) | Very Low | Low | Use constant-time comparisons | ✅ (CryptoKit) |
| Memory dump | Low | Critical | Clear sensitive vars on lock | ✅ Auto-lock |
| Backup extraction | Medium | Critical | File protection + Keychain exclusion | ✅ |
| App modification (tampering) | Low | Medium | Code signing (via App Store) | ✅ |
| Reverse engineering | Low | Low | Obfuscation (App Store) | ✅ |

---

## Security Checklist (Pre-Launch)

### Encryption
- [ ] SQLCipher linked correctly
- [ ] PRAGMA key applied on database open
- [ ] Key 32 bytes (AES-256)
- [ ] Encryption tested with actual DB

### Keychain
- [ ] Key stored in Keychain (not UserDefaults)
- [ ] Accessibility: `whenUnlockedThisDeviceOnly`
- [ ] No backup attribute
- [ ] Tested on device (not just simulator)

### Authentication
- [ ] FaceID/TouchID working on physical device
- [ ] PIN fallback working
- [ ] PIN hashing correct (PBKDF2)
- [ ] Auto-lock timer working

### Data Protection
- [ ] Database file has correct protection class
- [ ] Sensitive memory cleared on lock
- [ ] No financial data in logs
- [ ] No plaintext in NSUserDefaults

### Testing
- [ ] Unit tests pass (Keychain, Encryption)
- [ ] Integration tests pass (DB encryption)
- [ ] Security validation checklist ✅
- [ ] Manual testing on real device ✅

---

## Future Enhancements

1. **Key Rotation**: Option to regenerate DB/export keys safely
2. **Jailbreak Detection**: Detect if device is jailbroken
3. **Pasteboard Security**: Clear sensitive data from clipboard
4. **Mac Import Tool**: Local-only viewer/importer for `.shopvault`
5. **Secure Backup**: Encrypted backup container with separate key
6. **iCloud Sync**: End-to-end encrypted sync (proposal stage)
7. **PIN Hash Upgrade**: Re-hash legacy `v2l*`/`v2$*` SHA256 PIN hashes to PBKDF2-HMAC-SHA256 `v3l*` on the next successful PIN entry, so no installed user is left on a single-round SHA256 hash.

---

See `ARCHITECTURE.md` for system design details.
