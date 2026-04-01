# Deployment guide

This document covers building release APKs for distribution and optional WebDAV server setup.

---

## Overview

Kinetic Link is a **local-first** family app with **optional** remote sync.

- **Parent app** (Android + iOS) — stores personal tasks & notes locally, optionally syncs with WebDAV
- **Kids app** (Android) — currently a placeholder; future phases will push tasks from parent
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

### First-time setup

**1. Copy the repo's hub folder to Unraid**

From your dev machine (or directly on the Unraid bash terminal):
```bash
# Option A — copy over the network (from your dev machine)
scp -r hub/ root@<unraid-ip>:/mnt/user/appdata/kinetic/

# Option B — clone the whole repo on Unraid
ssh root@<unraid-ip>
git clone <repo-url> /mnt/user/appdata/kinetic/kinetic
cd /mnt/user/appdata/kinetic/kinetic/hub
```

**2. Set up the environment file**
```bash
cd /mnt/user/appdata/kinetic/hub   # or wherever you placed hub/
cp .env.example .env
nano .env
# Set:
#   COUCHDB_USER      — admin username
#   COUCHDB_PASSWORD  — admin password (not the mesh key)
#   HUB_ID            — e.g. "the-smiths-hub"
#   MESH_KEY_HEX      — output of: python3 -c "import secrets; print(secrets.token_hex(32))"
#   COUCH_PORT        — leave as 5984 unless you have a conflict
```

**3. Add the stack in Compose Manager**

- Go to Unraid UI → **Docker** tab → **Compose** (top menu).
- Click **Add Stack**, give it a name (e.g. `kinetic-hub`).
- Set the **Compose file path** to the `docker-compose.yml` inside your hub folder, e.g.:
  `/mnt/user/appdata/kinetic/hub/docker-compose.yml`
- Set the **Environment file** to the `.env` you just edited.
- Click **Compose Up**.

Compose Manager will pull the images and start all four services (`couchdb`, `couch_init`, `advertiser`, `enroll`).

**4. Verify**

In the Unraid terminal:
```bash
curl -s http://localhost:5984/ | python3 -m json.tool
# Should return CouchDB welcome JSON

docker ps
# couchdb, advertiser and enroll should show "Up"; couch_init "Exited (0)"
```

### Persistent data

CouchDB stores its data in the named volume `couch_data`. On Unraid, Docker named volumes live under `/var/lib/docker/volumes/`. If you want the data in your array instead (recommended for backup), map it explicitly in `docker-compose.yml`:

```yaml
volumes:
  - /mnt/user/appdata/kinetic/couch_data:/opt/couchdb/data
```

### Auto-start on boot

Compose Manager automatically restarts stacks that were running before a reboot — no extra configuration needed.

### Checking logs

Either use the Unraid Docker tab → click the container → **Logs**, or from the terminal:
```bash
docker compose -f /mnt/user/appdata/kinetic/hub/docker-compose.yml logs -f
```

---

## 3. Enrolling devices

Enrollment replaces the old `--dart-define` build-time key distribution.  **Apps downloaded from an app store work without a custom build.**

### Enrollment flow

```
1. Hub starts → enroll service serves QR at http://<hub-ip>:8765/enroll
2. Parent opens parent app (first launch) → scans hub QR
   → mesh key + CouchDB credentials stored in Android Keystore / iOS Keychain
3. Parent opens Settings → "Kindertoestel toevoegen"
   → shows a new QR containing the stored mesh key + credentials
4. Child device opens kids app (first launch) → scans parent QR
   → key + credentials stored in the device's secure enclave
```

After step 4, both apps connect to the hub via mDNS and sync automatically.

### Enrolling additional parent devices

Open **Instellingen → Verbinden met hub** on the new device and scan the hub QR again.

### Enrolling additional child devices

Open **Instellingen → Kindertoestel toevoegen** on any enrolled parent device and scan from the new child device.

### Standalone mode (no hub)

During first launch the parent app offers **"Overslaan — zonder hub gebruiken"**.  Personal task management (the Tasks tab) works fully offline.  Family sync features (Approvals, XP, help tickets) are disabled until the parent enrolls via Settings later.

---

## 4. Building app releases

No secrets are embedded in the binary.  A plain release build works for any family.

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

> **Dev builds** (plain `flutter run` without any extra arguments) use a
> built-in dev key and `kinetic`/`changeme` credentials (`kDebugMode` guard).
> This matches `hub/.env.example` defaults for local development and is safe
> because the guard is stripped in release builds.

---

## 5. Running the hub locally (development)

For local development, start the hub using the default dev credentials and then run the Flutter app with `flutter run` (no enrollment needed — `kDebugMode` uses the built-in dev key):

```bash
# Terminal 1 — start hub
cd hub
cp .env.example .env   # defaults are fine for dev
docker compose up

# Terminal 2 — run parent app against the dev hub
cd apps/parent
flutter run
```

The dev mesh key `de10de10de10de10...` is used automatically in `kDebugMode` — no scanning or enrollment step is needed during development.

---

## 6. Melos build scripts

Two Melos scripts are defined for convenience:

```bash
melos run build_parent   # flutter build apk --release for apps/parent
melos run build_kids     # flutter build apk --release for apps/kids
```

Because enrollment is now runtime-based, these produce fully functional release APKs with no extra arguments needed.

---

## 7. Updating a live deployment

### Hub update

CouchDB upgrades are handled by changing the image tag and restarting:

```bash
cd hub
# Edit docker-compose.yml: couchdb image tag (e.g. couchdb:3.5)
docker compose pull
docker compose up -d
```

Data is in the named volume `couch_data` and survives image upgrades.

### App update

1. Rebuild the APK (`flutter build apk --release`).
2. Distribute via `adb install` or sideload.
3. The mesh key is stored in the device's secure enclave and survives app updates — no re-enrollment needed.

---

## 8. Security notes

- **The mesh key is a shared family secret** — anyone with the key can decrypt all family data stored in CouchDB.  It is transmitted only within your LAN via a QR code scan and then stored in the OS-backed hardware secure enclave on each device.
- **`hub/.env` must be kept secret** — it contains both the CouchDB password and the mesh key.  Do not commit it to version control (it is listed in `.gitignore`).
- **Change the default CouchDB password** (`changeme`) before running the hub outside a trusted LAN.
- **The enrollment server (port 8765) should not be exposed to the internet** — it broadcasts the mesh key in plaintext over the local network.  Block this port on your router.
- **CouchDB (port 5984) should not be exposed to the internet** — the default Docker Compose config binds to all interfaces.  Ensure your router does not forward that port externally.
- **Mesh key rotation** requires re-enrolling all devices: generate a new key, update `hub/.env`, restart the hub, and have each device re-enroll from the hub QR (Settings → Verbinden met hub / Kindertoestel toevoegen).  Old CouchDB data will appear empty until each device re-syncs after re-enrollment.
- **Stopping the enroll service** after all devices are enrolled reduces the attack surface: `docker compose stop enroll`.

