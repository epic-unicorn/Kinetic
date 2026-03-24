# Deployment guide

This document covers building release APKs, running the hub, managing secrets, and updating a live deployment.

---

## Overview

A complete Kinetic Link deployment consists of:

1. **Hub** — a Linux machine on the family LAN (Raspberry Pi 4 or Unraid server are ideal) running the Docker Compose stack.
2. **Parent app** — installed on one or more Android/iOS devices belonging to parents.
3. **Kids app** — installed on Android devices used by children.

All three components must share the same **mesh key**.  The hub never holds this key; it stores only encrypted blobs.

---

## 1. Generating a mesh key

Generate a random 32-byte (256-bit) key once per family and never change it (doing so invalidates all synced data):

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
# example output: a3f1c09e4b782d56...  (64 hex chars)
```

Keep this value secret; treat it like a password.  You will supply it as a `--dart-define` argument to every app build.

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
# Edit .env:
#   COUCHDB_USER   — admin username (anything, never shown in the app)
#   COUCHDB_PASSWORD — admin password (not the mesh key; used for replication auth)
#   HUB_ID         — a stable name for this hub, e.g. "the-smiths-hub"
#   COUCH_PORT     — leave as 5984 unless you remap

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
# All three services should show "running" / "exited 0"

curl -s http://localhost:5984/ | python3 -m json.tool
# Should return CouchDB welcome JSON
```

### Checking hub logs

```bash
docker compose logs couchdb      # CouchDB
docker compose logs advertiser   # mDNS advertiser
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

## 3. Building app releases

Both apps use `--dart-define` for all secrets.  Nothing sensitive is committed to the repository.

### Required `--dart-define` arguments

| Key | Description | Example |
|---|---|---|
| `MESH_KEY_HEX` | 64 hex chars — your family mesh key | `a3f1c09e...` |
| `COUCH_USER` | CouchDB admin username from `hub/.env` | `kinetic` |
| `COUCH_PASSWORD` | CouchDB admin password from `hub/.env` | `s3cr3t!` |

> **Dev builds** (plain `flutter run` / `flutter build` without `--dart-define`) fall back to a built-in dev key and `kinetic`/`changeme` credentials that match `hub/.env.example`.  This is intentional for local development but must never be used in a family deployment.

### Parent app (Android APK)

```bash
cd apps/parent

flutter build apk --release \
  --dart-define=MESH_KEY_HEX=<your-64-char-hex-key> \
  --dart-define=COUCH_USER=<username> \
  --dart-define=COUCH_PASSWORD=<password>

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Parent app (iOS)

```bash
cd apps/parent

flutter build ipa \
  --dart-define=MESH_KEY_HEX=<your-64-char-hex-key> \
  --dart-define=COUCH_USER=<username> \
  --dart-define=COUCH_PASSWORD=<password>

# Output: build/ios/ipa/*.ipa
```

### Kids app (Android APK)

```bash
cd apps/kids

flutter build apk --release \
  --dart-define=MESH_KEY_HEX=<your-64-char-hex-key> \
  --dart-define=COUCH_USER=<username> \
  --dart-define=COUCH_PASSWORD=<password>

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Installing on a device

```bash
# Connect device via USB with developer mode + USB debugging enabled
adb install build/app/outputs/flutter-apk/app-release.apk
```

Or transfer the APK via email / Google Drive and install from Files.

---

## 4. Running the hub locally (development)

---

## 3b. Running the hub on Unraid

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
#   COUCH_PORT        — leave as 5984 unless you have a conflict
```

**3. Add the stack in Compose Manager**

- Go to Unraid UI → **Docker** tab → **Compose** (top menu).
- Click **Add Stack**, give it a name (e.g. `kinetic-hub`).
- Set the **Compose file path** to the `docker-compose.yml` inside your hub folder, e.g.:
  `/mnt/user/appdata/kinetic/hub/docker-compose.yml`
- Set the **Environment file** to the `.env` you just edited.
- Click **Compose Up**.

Compose Manager will pull the images and start all three services (`couchdb`, `couch_init`, `advertiser`).

**4. Verify**

In the Unraid terminal:
```bash
curl -s http://localhost:5984/ | python3 -m json.tool
# Should return CouchDB welcome JSON

docker ps
# couchdb and advertiser should show "Up"; couch_init "Exited (0)"
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

## 4. Running the hub locally (development)

For local development, start the hub using the default dev credentials and then run the Flutter app with `flutter run` (no `--dart-define` needed):

```bash
# Terminal 1 — start hub
cd hub
cp .env.example .env   # defaults are fine for dev
docker compose up

# Terminal 2 — run parent app against the dev hub
cd apps/parent
flutter run
```

The dev mesh key baked into both apps matches nothing in production but works consistently across all dev machines running the same hub defaults.

---

## 5. Melos build scripts

Two Melos scripts are defined for convenience:

```bash
melos run build_parent   # flutter build apk --release for apps/parent
melos run build_kids     # flutter build apk --release for apps/kids
```

These run without `--dart-define`, producing APKs with the dev fallback key.  Pass additional arguments via `--` if needed:

```bash
# Not currently supported by Melos exec + flutter build in one step.
# Use the direct flutter build commands above for production builds.
```

---

## 6. Updating a live deployment

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

1. Rebuild the APK with the same `--dart-define` values.
2. Distribute via `adb install` or sideload.
3. The mesh key does not change — existing data continues to sync.

---

## 7. Security notes

- **The mesh key is a shared family secret** — anyone with the key can decrypt all family data stored in CouchDB.  Distribute it only by building the APK yourself and installing directly.
- **Change the default CouchDB password** before running the hub outside a trusted LAN.
- **CouchDB is not exposed to the internet** in the default Docker Compose config — port 5984 binds to all interfaces, so ensure your router does not forward that port externally.
- **Mesh key rotation** requires rebuilding and reinstalling both apps.  All data will need to be re-synced from a device that still holds the old plaintext in its local in-memory store, since changing the key makes old ciphertext unreadable.
