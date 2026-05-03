# Security Policy

## Reporting a Vulnerability

ShopVault handles encryption, PII, and authentication. If you discover a security vulnerability, **please do not open a public issue.**

Instead, contact the maintainers privately via:

- A confidential GitHub Security Advisory: https://github.com/YOUR_USERNAME/shopvault/security/advisories/new
- Or by direct message to a project maintainer

We aim to respond within 7 days.

## Scope

In-scope:
- Cryptographic vulnerabilities (key derivation, encryption, key management)
- Local storage security (SQLCipher, Keychain, file protection)
- Biometric / PIN authentication bypasses
- Snapshot export/import vulnerabilities
- Dependency vulnerabilities (SQLCipher Swift package)

Out of scope:
- Bugs requiring physical access to an unlocked device
- Issues in third-party iOS/macOS APIs themselves
- Theoretical attacks against properly-configured AES-256-GCM or PBKDF2

## Supported Versions

Only the latest `main` branch receives security updates.
