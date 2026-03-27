# Deployment guide

This document covers building release APKs, running the hub, managing secrets, and updating a live deployment.

---

## Overview

A complete Kinetic Link deployment consists of:

1. **Hub** — a Linux machine on the family LAN (Raspberry Pi 4 or Unraid server are ideal) running the Docker Compose stack.
2. **Parent app** — installed on one or more Android/iOS devices belonging to parents.
3. **Kids app** — installed on Android devices used by children.

All three components must share the same **mesh key**.  The hub holds the key and distributes it to apps at enrollment time via a QR code — the key is never baked into the app binary.

---

## 1. Generating a mesh key

Generate a random 32-byte (256-bit) key once per family and never change it (doing so invalidates all synced data):

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
# example output: a3f1c09e4b782d56...  (64 hex chars)
```

Paste this value as `MESH_KEY_HEX` in `hub/.env`.  **Keep the `.env` file secret** — treat it like a password manager vault file.

The key is distributed to each app at enrollment time via a QR code served by the hub; you never need to pass it to a build tool.

---

## 2. Running the hub

### Prerequisites

- Linux host (bare metal or VM) on the same LAN as all devices.
- Docker Engine ≥ 24 and Docker Compose v2.
- Port 5984 reachable from all devices (no extra firewall rule needed if they are on the same subnet).

> **macOS / Windows Docker Desktop** — `network_mode: host` is not supported.  The mDNS advertiser sidecar will not work inside the container.  Run `advertise.py` directly on the host instead (see [mDNS on macOS/Windows](#mdns-on-macoswindows)).

### First-time setup

```bash
cd hub

# 1. Copy and edit the environment file
cp .env.example .env
# Edit .env — uncomment and fill in all four values:
#   COUCHDB_USER        — admin username (anything, never shown in the app)
#   COUCHDB_PASSWORD    — admin password (not the mesh key)
#   HUB_ID              — a stable name for this hub, e.g. "the-smiths-hub"
#   MESH_KEY_HEX        — output of: python3 -c "import secrets; print(secrets.token_hex(32))"
#   COUCH_PORT          — leave as 5984 unless you remap

# 2. Start the stack
docker compose up -d
```

On first start, the `couch_init` container:
- Completes CouchDB single-node cluster setup.
- Creates the `_users` and `_replicator` system databases.
- Creates the `kinetic_family` application database.

Verify everything is running:

```bash
docker compose ps
# All four services should show "running" / "exited 0"
# (couchdb, couch_init, advertiser, enroll)

curl -s http://localhost:5984/ | python3 -m json.tool
# Should return CouchDB welcome JSON
```

### Checking hub logs

```bash
docker compose logs couchdb      # CouchDB
docker compose logs advertiser   # mDNS advertiser
docker compose logs enroll       # enrollment QR server
docker compose logs couch_init   # one-shot init (already exited)
```

### Stopping and restarting

```bash
docker compose down       # stop (data volume is preserved)
docker compose down -v    # stop AND delete all stored data
docker compose restart    # restart all services
```

### mDNS on macOS/Windows

When running Docker Desktop, run the advertiser directly on the host:

```bash
cd hub/advertise
pip install -r requirements.txt

# Set the same values as in your .env
COUCH_PORT=5984 HUB_ID=the-smiths-hub python advertise.py
```

Use a `launchd` plist (macOS) or a Scheduled Task / NSSM service (Windows) to keep this running at startup.

---

## 2b. Running the hub on Unraid

Unraid is Linux-based, so `network_mode: host` works correctly — mDNS broadcast works inside the container without any workaround.

### Prerequisites

- Unraid 6.10 or later.
- **Compose Manager** plugin installed from Community Applications (search "Compose Manager").
- The `hub/` folder from this repo accessible on your Unraid server (e.g. via a share or git clone to `/mnt/user/appdata/kinetic/`).

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

