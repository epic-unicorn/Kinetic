"""
advertise.py
Advertises the Kinetic hub as a _kinetic._tcp mDNS service on the local network.
The Flutter apps discover it via BonsoirMdnsDiscoveryService and sync to CouchDB.

Service attributes expected by BonsoirMdnsDiscoveryService:
  id   — stable unique device/hub ID
  role — 'hub' | 'parent' | 'child'
"""

import os
import socket
import time

from zeroconf import Zeroconf, ServiceInfo

port = int(os.environ.get("COUCH_PORT", "5984"))
hub_id = os.environ.get("HUB_ID", "kinetic-hub")

# Resolve the host's primary LAN IP.
# Using a UDP trick (no packet is actually sent) to find the outbound interface.
try:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
except OSError:
    ip = "127.0.0.1"

info = ServiceInfo(
    "_kinetic._tcp.local.",
    "kinetic-hub._kinetic._tcp.local.",
    addresses=[socket.inet_aton(ip)],
    port=port,
    properties={
        "id": hub_id,
        "role": "hub",
    },
)

zc = Zeroconf()
zc.register_service(info)
print(f"[kinetic-advertiser] Hub '{hub_id}' advertised as _kinetic._tcp @ {ip}:{port}", flush=True)

try:
    while True:
        time.sleep(60)
except KeyboardInterrupt:
    pass
finally:
    zc.unregister_service(info)
    zc.close()
    print("[kinetic-advertiser] Stopped.", flush=True)
