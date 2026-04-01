# Deployment guide

This document covers building release APKs for distribution and optional WebDAV server setup.

---

## Overview

Kinetic Link is a **local-first** family app with **optional** remote sync.

- **Parent app** (Android + iOS) — stores personal tasks & notes locally, optionally syncs with WebDAV
- **Kids app** (Android) — receives and completes tasks assigned by parent via WebDAV
- **WebDAV server** (optional) — any server (Nextcloud, Apache, etc.) for shared storage

There is **no centralized hub**. Users control where their data is stored.

---

## Building release APKs

### Prerequisites

- Flutter ≥ 3.19.3
- Android SDK with API 24+ build-tools
- A valid Android signing key (follow [Android docs](https://developer.android.com/studio/publish/app-signing))

### Step 1: Prepare signing configuration

Store your signing key in a safe location and create `android/key.properties`:

```properties
storeFile=/path/to/release-keystore.jks
storePassword=<keystore_password>
keyAlias=release
keyPassword=<key_password>
```

Update `android/app/build.gradle` if not already configured:

```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile file(keystoreProperties['storeFile'])
        storePassword keystoreProperties['storePassword']
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

### Step 2: Build parent app

```bash
cd apps/parent
flutter clean
flutter pub get
flutter build apk --release
# Output: build/app/outputs/flutter-app.apk
```

### Step 3: Build kids app

```bash
cd apps/kids
flutter clean
flutter pub get
flutter build apk --release
# Output: build/app/outputs/flutter-app.apk
```

### Step 4: Distribute

- **Parent app**: Share `apps/parent/build/app/outputs/flutter-app.apk` with parents
- **Kids app**: Sideload or share APK with guardians for installation on kids' devices

---

## Optional: WebDAV server setup

Users can optionally configure WebDAV sync in the parent app settings. The app will create the necessary folder structure automatically.

### Recommended WebDAV servers

**Nextcloud** (easiest for non-technical users)
- Built-in WebDAV server at `/remote.php/dav`
- No additional configuration needed
- Self-hosted or third-party providers available

**Apache with mod_dav**
- More lightweight
- Requires manual setup:

```apache
<Location /kinetic>
  DAV on
  AuthType Basic
  AuthName "Kinetic"
  AuthUserFile /etc/apache2/.htpasswd
  Require valid-user
</Location>
```

Then create a user:
```bash
htpasswd -c /etc/apache2/.htpasswd myusername
```

### Storage structure (created automatically)

Once a parent configures WebDAV, the app creates:

```
/kinetic/{username}/
├── tasks/
│   ├── personal.ics    — parent's personal tasks (encrypted with personal key)
│   └── shared.ics      — shared/family tasks (encrypted with family key)
├── notes/
│   ├── personal.ics    — parent's personal notes (encrypted with personal key)
│   └── shared.ics      — shared/family notes (encrypted with family key)
└── shared/
    ├── load/{username}.json    — workload metrics (family key)
    └── proposals/{id}.json     — partner proposals (family key)
```

**Security:**
- Personal key: random 32 bytes per device, exportable as recovery JSON
- Family key: derived from WebDAV password using PBKDF2(password, "kinetic-family-key", 100000 rounds)
- Server sees only AES-256-GCM ciphertext; decryption keys never transmitted

---

## Running a development WebDAV server (Docker)

For testing, you can run a local WebDAV server with Docker:

```bash
docker run -d \
  --name webdav \
  -p 8080:80 \
  -e USERNAME=testuser \
  -e PASSWORD=testpass \
  -v webdav-data:/data \
  bytemark/webdav
```

Access via `http://localhost:8080` with credentials `testuser:testpass`.

In the app, use:
- Server URL: `http://<your-machine-ip>:8080`
- Username: `testuser`
- Password: `testpass`

---

## Notes for production deployment

1. **Use HTTPS** — production WebDAV servers must use TLS (e.g. with Let's Encrypt)
2. **Secure credentials** — users should use strong passwords; the family key derives from this
3. **Backups** — users remain responsible for backing up their WebDAV server
4. **Data recovery** — if a user loses their personal key recovery JSON, they cannot decrypt that device's personal tasks; recommend exporting early and storing securely
5. **No cloud backup** — Kinetic does NOT send data to any cloud service; all storage is user-controlled

---

## Troubleshooting

**App won't connect to WebDAV server**
- Verify server URL is correct and accessible: open it in a browser or test with `curl -I <url>`
- Check username and password
- Ensure server is not blocking the app's HTTP client

**WebDAV folder structure not created**
- The app auto-creates on first sync attempt
- Check that your WebDAV user has write permission

**Tasks not syncing**
- WebDAV must be configured in Settings
- Check internet connection
- Manually trigger sync from Settings > WebDAV Configuration

---

## First-time user experience

When parents first open the app, it works fully offline:

1. **Tasks tab** — manage personal tasks (SQLite local storage)
2. **Notes tab** — create and edit notes (local only)
3. **Settings tab** → **WebDAV Configuration** — optionally connect to a WebDAV server for family sync

No account signup required. No enrollment QR codes. Users own their data from day one.

### Enabling family sync

Once two parents configure the **same WebDAV server** with **the same username/password**:

1. Their personal tasks/notes remain in private, personal-only folders
2. Shared tasks and notes are synced to `/kinetic/shared/` (encrypted with family key)
3. Partner proposals and workload metrics appear in the **Partner** tab
4. Kids app can be pushed tasks from parent app (future phase)

---

## Building app releases

No secrets are embedded in the binary. A plain release build works for any family (with or without WebDAV).

```bash
# Parent app
cd apps/parent
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Kids app
cd apps/kids
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

For iOS:

```bash
cd apps/parent
flutter build ipa
# Output: build/ios/ipa/*.ipa
```

### Installing on a device

```bash
# Connect device via USB with developer mode + USB debugging enabled
adb install build/app/outputs/flutter-apk/app-release.apk
```

Or transfer the APK via email / Google Drive and install from Files.

---

## Local development with WebDAV

For local testing of WebDAV features, run a simple WebDAV server in Docker:

```bash
docker run -d \
  --name webdav-test \
  -p 8080:80 \
  -e USERNAME=devuser \
  -e PASSWORD=devpass \
  -v webdav-test-data:/data \
  bytemark/webdav
```

Then in the app (Settings > WebDAV Configuration):
- Server URL: `http://<your-machine-ip>:8080`
- Username: `devuser`
- Password: `devpass`

All data will be stored in that local WebDAV server (encrypted on-device).

---

## Melos build scripts

Two Melos scripts are defined for convenience:

```bash
melos run build_parent   # flutter build apk --release for apps/parent
melos run build_kids     # flutter build apk --release for apps/kids
```

These produce fully functional release APKs ready for distribution.

---

## 8. Security notes

- **The mesh key is a shared family secret** — anyone with the key can decrypt all family data stored in CouchDB.  It is transmitted only within your LAN via a QR code scan and then stored in the OS-backed hardware secure enclave on each device.
- **`hub/.env` must be kept secret** — it contains both the CouchDB password and the mesh key.  Do not commit it to version control (it is listed in `.gitignore`).
- **Change the default CouchDB password** (`changeme`) before running the hub outside a trusted LAN.
- **The enrollment server (port 8765) should not be exposed to the internet** — it broadcasts the mesh key in plaintext over the local network.  Block this port on your router.
- **CouchDB (port 5984) should not be exposed to the internet** — the default Docker Compose config binds to all interfaces.  Ensure your router does not forward that port externally.
- **Mesh key rotation** requires re-enrolling all devices: generate a new key, update `hub/.env`, restart the hub, and have each device re-enroll from the hub QR (Settings → Verbinden met hub / Kindertoestel toevoegen).  Old CouchDB data will appear empty until each device re-syncs after re-enrollment.
- **Stopping the enroll service** after all devices are enrolled reduces the attack surface: `docker compose stop enroll`.

