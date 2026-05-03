# Laptop Data Access

ShopVault keeps the primary database encrypted on the iPhone with SQLCipher. For laptop access, the app creates a separate encrypted export file instead of exposing the iPhone database or Keychain key.

## Export Format

- File extension: `.shopvault`
- Envelope: JSON
- Payload: Base64-encoded AES-256-GCM ciphertext
- KDF: PBKDF2-HMAC-SHA256, 600,000 iterations, random 16-byte salt
- Payload after decryption: JSON with table arrays under `tables`

The export contains customer phone, email, and address decrypted inside the encrypted payload, so a laptop interface can work without the iOS Keychain key.

## Workflow

1. Open ShopVault on the iPhone.
2. Go to Settings -> Laptop Access.
3. Choose a strong export password.
4. Authenticate with Face ID, Touch ID, or device passcode.
5. Share the `.shopvault` file to your Mac with AirDrop or Files.
6. Build your laptop interface to ask for the export password and decrypt the payload locally.

## Security Notes

- The export password is not stored by the app.
- The exported file is encrypted before it leaves the app.
- Losing the export password means the exported file cannot be decrypted.
- This is a snapshot export, not live sync. A future local Mac interface can import the newest export whenever needed.
