# Kinetic WebDAV

Shared sync, crypto, and serialization logic for Kinetic Link.

## Features

- **WebDAV client**: HTTP operations (PROPFIND, PUT, GET, DELETE) for file sync
- **iCal serialization**: Parse and serialize tasks/notes as `.ics` files (RFC 5545) with custom properties
- **AES-256-GCM encryption**: End-to-end encryption with PBKDF2 key derivation
- **Secure storage**: Hardware-backed secure storage abstraction
- **Sync orchestration**: Last-Write-Wins (LWW) merge strategy for multi-device sync

## Custom iCal Properties

Tasks and notes store metadata in escaped iCal DESCRIPTION field:
- `xKineticParentId` — ID of the parent who created/modified the task
- `xKineticCategory` — Task category (for compatibility)
- `xKineticXpReward` — XP reward value
- `xKineticTargetKidId` — UUID of the child this task is assigned to (only set for kid-targeted tasks)

## QR Payload Formats

### Partner Sharing (FamilyKeyShareScreen)
```javascript
{
  "v": 1,
  "type": "family",
  "url": "https://nextcloud.example.com/remote.php/webdav/",
  "user": "parent@example.com",
  "pw": "...",
  "key": "<base64-family-key>"
}
```

### Kids Enrollment (KidsEnrollmentQrScreen)
```javascript
{
  "v": 1,
  "type": "kids",
  "url": "https://nextcloud.example.com/remote.php/webdav/",
  "user": "parent@example.com",
  "pw": "...",
  "key": "<base64-family-key>",
  "kid": "<uuid-for-this-child-device>"
}
```

## Exports

### Classes

- `KineticEncryption`: Static methods for encrypt/decrypt, key derivation, and recovery JSON format
- `WebDavClient`: HTTP client for WebDAV operations
- `SyncConfig`: Holds WebDAV credentials and encryption keys (personal/family)
- `SecureKeyValueStore`: Abstract base for secure storage implementations
- `PersonalTask` / `PersonalNote`: Domain models
- `PartnerProposal`: Domain model for parent proposals
- `KidsTask`: Domain model for child-assigned tasks

### Key Methods

**KineticEncryption**:
- `generateFamilyKey()` → random 32-byte key
- `exportFamilyKeyQrPayload(key, serverUrl, username)` → JSON string for QR
- `importFamilyKeyQrPayload(payload)` → deserialize from QR
- `exportKidsEnrollmentQrPayload(familyKey, serverUrl, username, kidId)` → JSON string for kids enrollment QR
- `importKidsEnrollmentQrPayload(payload)` → `{familyKey, serverUrl, username, password, kidId}`
- `exportRecoveryJson(keyBytes, username)` → JSON string with encrypted key (for backup)
- `importRecoveryJson(jsonString, password)` → keyBytes (restores from backup)
- `encrypt(plaintext, keyBytes)` → AES-256-GCM ciphertext
- `decrypt(ciphertext, keyBytes)` → plaintext or null on auth failure

**WebDavClient**:
- `propfind(path)` → `List<WebDavEntry>` for a collection (direct children only)
- `put(path, bytes)` → Upload file; optional `etag` for conditional PUT
- `get(path)` → Download raw bytes
- `delete(path)` → Delete file (404 treated as success)

**SyncConfig**:
- Stores `serverUrl`, `username`, `password`, `parentId`
- Stores `personalKeyBytes` and optional `familyKeyBytes`
- Accessor: `baseUrl` (normalized WebDAV path)

## Secure Storage Keys

Each app's `WebDavConfigRepository.load()` reads these keys from secure storage:

```
kinetic_webdav_server_url        — WebDAV server URL
kinetic_webdav_username           — WebDAV username
kinetic_webdav_password           — WebDAV password
kinetic_webdav_personal_key       — Personal key (base64)
kinetic_webdav_family_key         — Family key (base64, optional)
kinetic_webdav_parent_id          — Parent ID (optional)
kinetic_partner_paired            — '1' if partner is paired, '0' otherwise
kinetic_enrolled_kids             — JSON list of enrolled kids (parent only)
kinetic_kid_id                    — This device's child UUID (kids only)
```

## Encryption Architecture

### Personal Key
- Derived from **user password** + **username salt** PBKDF2
- Encrypts: personal tasks, personal notes
- Individual to each user — not shared
- Exportable as recovery JSON for multi-device migration

### Family Key
- Derived from **family QR share** or **kids enrollment QR**
- Encrypts: shared tasks, assigned tasks (with xKineticTargetKidId), shared notes, proposals, metrics
- Shared among all family devices that scanned the QR

### Kid-Specific Filtering
- Each kids device stores its unique `kinetic_kid_id` UUID during enrollment
- On sync pull, tasks with `xKineticTargetKidId != myKidId` and `xKineticTargetKidId != null` are filtered out
- Parent can target tasks to specific kids by setting `targetKidId` in the DB column

## Backup Format

### `.kbak2` (Combined Backup)
Unencrypted JSON wrapper:
```javascript
{
  "version": 2,
  "exportedAt": "2026-04-09T12:34:56Z",
  "usernameHint": "parent@example.com",
  "personalKey": "<base64-personal-key>",
  "database": "<base64-of-encrypted-kbak-blob>"
}
```

The `database` field contains the output of `DatabaseBackupService` (encrypted `.kbak` blob with all tables).
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
- WebDAV client with mocked HTTP
- Key derivation consistency
- Recovery JSON import/export

## Development

This package is pure Dart (Flutter-agnostic for serialization logic, but uses Flutter Secure Storage for key persistence).

```bash
dart analyze
dart format --set-exit-if-changed .
```
