"""
enroll.py
Serves a one-time-use LAN enrollment QR for the Kinetic hub.

Endpoint: GET /enroll
  Returns an HTML page with a QR code image.
  The QR payload is a standard Kinetic pairing JSON containing the
  mesh key, CouchDB credentials, hub device ID and role=hub.

Security:
  - Bind address is 0.0.0.0 but should be restricted to LAN via firewall /
    Docker network.  Never expose port 8765 to the WAN.
  - The mesh key is read from the MESH_KEY_HEX environment variable which is
    persisted in the Docker volume via the init container.
  - The endpoint does NOT consume/expire tokens in this minimal version;
    it is intended to be used once during family setup.  For additional
    security you can stop the enroll container after enrollment.
"""

import base64
import json
import os
import socket
import uuid

import qrcode
import qrcode.image.svg
from flask import Flask, Response

app = Flask(__name__)

# ---------------------------------------------------------------------------
# Configuration from environment
# ---------------------------------------------------------------------------
MESH_KEY_HEX: str = os.environ["MESH_KEY_HEX"]          # required
COUCH_USER: str = os.environ.get("COUCHDB_USER", "kinetic")
COUCH_PASSWORD: str = os.environ.get("COUCHDB_PASSWORD", "changeme")
HUB_ID: str = os.environ.get("HUB_ID", "kinetic-hub")
PORT: int = int(os.environ.get("ENROLL_PORT", "8765"))


def _mesh_key_base64() -> str:
    raw = bytes.fromhex(MESH_KEY_HEX)
    return base64.b64encode(raw).decode()


def _build_payload() -> str:
    """Build the same base64-encoded JSON that PairingService.generatePairingPayload produces."""
    payload = {
        "v": 1,
        "id": HUB_ID,
        "pk": "",          # hub has no Ed25519 key — apps ignore this for hub role
        "mk": _mesh_key_base64(),
        "role": "hub",
        "label": "Kinetic Hub",
        "cu": COUCH_USER,
        "cp": COUCH_PASSWORD,
    }
    json_bytes = json.dumps(payload, separators=(",", ":")).encode()
    return base64.b64encode(json_bytes).decode()


def _qr_svg(data: str) -> str:
    factory = qrcode.image.svg.SvgPathImage
    img = qrcode.make(data, image_factory=factory, error_correction=qrcode.constants.ERROR_CORRECT_M)
    import io
    buf = io.BytesIO()
    img.save(buf)
    return buf.getvalue().decode()


@app.get("/enroll")
def enroll():
    payload = _build_payload()
    svg = _qr_svg(payload)

    # Detect LAN IP for display
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            lan_ip = s.getsockname()[0]
    except OSError:
        lan_ip = "unknown"

    html = f"""<!DOCTYPE html>
<html lang="nl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Kinetic Hub — Enrolleren</title>
  <style>
    body {{ font-family: sans-serif; background: #1e1e1e; color: #e0e0e0;
            display: flex; flex-direction: column; align-items: center;
            justify-content: center; min-height: 100vh; gap: 24px; margin: 0; }}
    h1 {{ color: #44BBA4; font-size: 1.6rem; text-align: center; }}
    p  {{ color: #aaa; text-align: center; max-width: 360px; }}
    .qr-wrap {{ background: #fff; padding: 16px; border-radius: 12px; }}
    .qr-wrap svg {{ display: block; width: 240px; height: 240px; }}
    code {{ background: #333; padding: 2px 6px; border-radius: 4px; font-size: .85rem; }}
  </style>
</head>
<body>
  <h1>Kinetic Hub</h1>
  <p>Scan deze QR-code met de ouder-app om je telefoon te verbinden met de hub.<br>
     Adres: <code>http://{lan_ip}:{PORT}/enroll</code></p>
  <div class="qr-wrap">{svg}</div>
  <p>Na het scannen kan je de kindertelefoon koppelen via<br>
     <strong>Instellingen → Kindertoestel toevoegen</strong>.</p>
</body>
</html>"""

    return Response(html, mimetype="text/html")


if __name__ == "__main__":
    print(f"[kinetic-enroll] Serving enrollment QR at http://0.0.0.0:{PORT}/enroll", flush=True)
    app.run(host="0.0.0.0", port=PORT)
