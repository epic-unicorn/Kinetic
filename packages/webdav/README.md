# Kinetic WebDAV

Shared sync, crypto, and serialization logic for Kinetic Link.

## Features

- **WebDAV client**: HTTP operations (PROPFIND, PUT, GET, DELETE) for file sync
- **iCal serialization**: Parse and serialize tasks/notes as `.ics` files (RFC 5545)
- **AES-256-GCM encryption**: End-to-end encryption with PBKDF2 key derivation using hardware-backed secure storage
- **Sync orchestration**: Last-Write-Wins (LWW) merge strategy for multi-device sync

## Exports

### Classes

- `KineticEncryption`: Static methods for encrypt/decrypt, key derivation, and recovery JSON format
- `WebDavClient`: HTTP client for WebDAV operations
- `SyncConfig`: Holds WebDAV credentials and encryption keys (personal/family)
- `PersonalTask` / `PersonalNote`: Domain models (from parent app)
- `KidTask`: Domain model for child-assigned tasks (from kids app)

### Key Methods

**KineticEncryption**:
- `derivePersonalKey(password, username)` → generates random salt + PBKDF2 key
- `encrypt(plaintext, keyBytes)` → AES-256-GCM ciphertext
- `decrypt(ciphertext, keyBytes)` → plaintext or null on auth failure
- `exportRecoveryJson(keyBytes, username)` → JSON string with encrypted key (for backup)
- `importRecoveryJson(jsonString, password)` → keyBytes (restores from backup)

**WebDavClient**:
- `propfind(path)` → List of file hrefs in directory
- `put(path, content)` → Upload file
- `get(path)` → Download file content
- `delete(path)` → Delete file

**SyncConfig**:
- Stores `webdavUrl`, `username`, `password`
- Stores `personalKeyBytes` and `familyKeyBytes`
- Persists via secure storage (Flutter Secure Storage)

## Encryption Architecture

### Personal Key
- Derived from **user password** + **username salt**
- Encrypts: personal tasks, personal notes
- Individual to each user — not shared

### Family Key
- Derived from **family code** + **family name salt**
- Encrypts: shared tasks, assigned tasks, shared notes, workload metrics, proposals
- Shared among all family devices

### Recovery Format
Personal keys can be exported as encrypted JSON for multi-device migration:
```json
{
  "v": 1,
  "username": "john",
  "salt": "base64...",
  "encryptedKey": "base64..."
}
```
The encrypted key is re-encrypted using a temporary key derived from the user's password at import time.

## iCal Format

Tasks and notes are serialized as iCalendar (RFC 5545) with custom properties:

**Task properties**:
- `SUMMARY`: task title
- `DESCRIPTION`: task notes
- `DTSTART` / `DUE`: dates
- `CATEGORIES`: category tag
- `X-KINETIC-PRIORITY`: priority level
- `X-KINETIC-ASSIGNED-TO`: child assignment
- `X-KINETIC-REPEAT`: recurrence rule (daily/weekly/monthly)
- `RRULE`: standard iCal recurrence

**Note properties**:
- `SUMMARY`: note title
- `DESCRIPTION`: markdown body
- `DTSTART`: creation date
- `X-KINETIC-SHARED`: true/false

## Testing

```bash
flutter test
```

Tests cover:
- Encryption/decryption round-trips
- iCal serialization/parsing
- WebDAV PROPFIND mocking
- Key derivation consistency
- Recovery JSON import/export

## Development

This package is pure Dart (Flutter-agnostic for serialization logic, but uses Flutter Secure Storage for key persistence).

```bash
dart analyze
dart format --set-exit-if-changed .
```
