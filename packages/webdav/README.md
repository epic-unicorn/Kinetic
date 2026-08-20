# Kinetic WebDAV

Shared sync, crypto, and serialization logic for Kinetic Link.

## Features

- **WebDAV client**: HTTP operations (PROPFIND, PUT, GET, DELETE) for file sync
- **iCal serialization**: Parse and serialize tasks/notes as `.ics` files (RFC 5545) with custom properties
- **AES-256-GCM encryption**: End-to-end encryption of remote `.ics` / JSON with a random 32-byte key (PBKDF2 exists only as a legacy family-key helper)
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
  "v": 2,
  "type": "family",
  "url": "https://nextcloud.example.com/remote.php/webdav/",
  "user": "parent@example.com",
  "ent": "<base64 16-byte BIP-39 entropy>"
}
```

The partner payload does **not** include the WebDAV password. Each parent keeps their own WebDAV login. The scanner reconstructs the 12-word mnemonic from `ent` and derives the same 32-byte AES key. Partners can also type the words instead of scanning.

### Kids Enrollment (KidsEnrollmentQrScreen)
```javascript
{
  "v": 2,
  "type": "kids",
  "url": "https://nextcloud.example.com/remote.php/webdav/",
  "user": "parent@example.com",
  "key": "<base64-family-key>",
  "kid": "<uuid-for-this-child-device>"
}
```

v2 has **no** `pw`. The kids app asks for the WebDAV password after the scan. Import still accepts v1 payloads that include `pw`.

## Exports

### Classes

- `KineticEncryption`: AES-256-GCM, random keys, QR payloads
- `KineticVault`: BIP-39 mnemonic → 32-byte AES key, quiz helpers, `.kvault` wrap/unwrap, `vault.meta` canary
- `KineticVaultRemote`: GET/PUT `/kinetic/{user}/vault.meta`
- `WebDavClient`: HTTP client for WebDAV operations
- `SyncConfig`: Holds WebDAV credentials and encryption keys (personal/family)
- `SecureKeyValueStore`: Abstract base for secure storage implementations
- `PersonalTask` / `PersonalNote`: Domain models
- `PartnerProposal`: Domain model for parent proposals
- `KidsTask`: Domain model for child-assigned tasks

### Key Methods

**KineticEncryption**:
- `generatePersonalKey()` / `generateFamilyKey()` → random 32-byte keys
- `deriveFamilyKey(password)` → PBKDF2-HMAC-SHA-256 (legacy / migration only)
- `exportFamilyKeyQrPayload(key, serverUrl, username)` → JSON string for QR
- `importFamilyKeyQrPayload(payload)` → `{familyKey, serverUrl, username}`
- `exportKidsEnrollmentQrPayload(familyKey, serverUrl, username, {password, kidId})` → kids enrollment QR (omit `password` for v2)
- `importKidsEnrollmentQrPayload(payload)` → `{familyKey, serverUrl, username, password, kidId}` (`password` empty on v2)
- `exportRecoveryJson(keyBytes, usernameHint)` → JSON with **plaintext** base64 `personalKey`
- `importRecoveryJson(jsonString)` → 32-byte key (no password)
- `encrypt(plaintext, keyBytes)` → AES-256-GCM ciphertext
- `decrypt(ciphertext, keyBytes)` → plaintext or throws on auth failure

**KineticVault**:
- `deriveAesKey(phrase)` → 32-byte AES key (BIP-39 PBKDF2-HMAC-SHA512, empty passphrase, first 32 bytes of seed)
- `generateMnemonic()` / `parseMnemonic()` / `isValidMnemonic()`
- `wrapBackup` / `unwrapBackup` → `.kvault`
- `sealCanary` / `openCanary` / `KineticVaultRemote.probe` / `ensureMeta`

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
kinetic_webdav_personal_key       — Personal AES key (base64)
kinetic_webdav_personal_entropy   — 16-byte BIP-39 entropy for re-reveal (optional)
kinetic_webdav_username           — WebDAV username
kinetic_webdav_password           — WebDAV password
kinetic_vault_ready              — '1' after personal vault create/restore
kinetic_webdav_family_key         — Family AES key (base64, optional)
kinetic_webdav_family_entropy     — 16-byte BIP-39 entropy for family QR (optional)
kinetic_webdav_parent_id          — Parent ID (optional)
kinetic_partner_paired            — '1' if partner is paired, '0' otherwise
kinetic_enrolled_kids             — JSON list of enrolled kids (parent only)
kinetic_kid_id                    — This device's child UUID (kids only)
```

## Encryption Architecture

Remote files (`.ics`, proposal JSON, presence) are AES-256-GCM. Local SQLite is **not** encrypted.

### Personal Key
- 12 English BIP-39 words, shown at vault creation (3-word quiz, no skip)
- Derived with PBKDF2-HMAC-SHA512 (2048 rounds, salt `mnemonic`); first 32 bytes of the 64-byte seed are the AES-256-GCM key
- The derived key is stored in Flutter Secure Storage after unlock. The 16-byte entropy may also be stored so Settings can show the words again behind the device lock. Paper is the only off-device backup.
- Encrypts: personal tasks, personal notes, `.kvault` backups, `/kinetic/{user}/vault.meta`
- **Not** derived from the WebDAV password. The same phrase unlocks a file restore and a WebDAV restore

### Family Key
- Same 12-word BIP-39 model as the personal vault; derived AES-256-GCM key
- QR v2 carries **16 bytes of entropy**, never the WebDAV password
- Fingerprint: first 4 hex chars of SHA-256(family key) for visual confirmation
- Encrypted copy at `/kinetic/{user}/family.key.enc` (wrapped with the personal key) so a personal-phrase restore also recovers the family key
- Kids enrollment QR v2 carries the family key **without** the WebDAV password; the kids app prompts for it. v1 payloads with `pw` still import.

### Kid-Specific Filtering
- Each kids device stores its unique `kinetic_kid_id` UUID during enrollment
- On sync pull, tasks with `xKineticTargetKidId != myKidId` and `xKineticTargetKidId != null` are filtered out
- Parent can target tasks to specific kids by setting `targetKidId` in the DB column

## Backup Format

App-level combined backup lives in the parent app (`FullBackupService.exportVaultToBytes`).

### `.kvault`
```javascript
{
  "version": 1,
  "format": "kvault",
  "exportedAt": "2026-08-20T12:34:56Z",
  "usernameHint": "parent@example.com",
  "ciphertext": "<base64 AES-256-GCM>"
}
```

The ciphertext is the database snapshot (and theme) encrypted with the derived vault key. No mnemonic, no raw key, no WebDAV password.

### `vault.meta`
Small AES-GCM canary at `/kinetic/{username}/vault.meta`. Decrypt OK → right phrase. 404 → no vault on that server. MAC failure → wrong phrase.

Legacy `.kbak2` is not written anymore. The parent welcome screen can still import it once, then rotates to a new mnemonic (a random 0.2 key cannot become BIP-39 words). `exportRecoveryJson` remains on `KineticEncryption` for tests.

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
- Random key generation vs legacy `deriveFamilyKey`
- BIP-39 mnemonic checksum, seed prefix, `.kvault` wrap/unwrap, `vault.meta` probe

## Development

This package is pure Dart (Flutter-agnostic for serialization logic, but uses Flutter Secure Storage for key persistence).

```bash
dart analyze
dart format --set-exit-if-changed .
```
