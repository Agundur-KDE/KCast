#!/usr/bin/env bash
# Checks the prerequisites KCast needs, before you go looking for a bug in
# the widget itself: catt installed, a Chromecast actually discoverable
# (mDNS), and the Cast control port reachable if you have a device IP handy.

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
hint() { echo -e "    ${YELLOW}→${NC} $1"; }

HOST="${1:-}"

echo "KCast Setup-Check"
echo

# 1. catt installed
if command -v catt >/dev/null 2>&1; then
    ok "catt gefunden ($(command -v catt))"
else
    fail "catt nicht installiert"
    hint "pip install catt  (oder Distro-Paket, falls vorhanden)"
    exit 1
fi

# 2. mDNS/Zeroconf discovery actually finds a device — the real
# end-to-end check, catches firewall/multicast/VLAN issues in one go.
echo
echo "Scanne Netzwerk (catt scan, ~5s)…"
SCAN_JSON=$(timeout 10 catt scan -j 2>/dev/null)
DEVICE_COUNT=$(echo "$SCAN_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo 0)

if [[ "$DEVICE_COUNT" -gt 0 ]]; then
    NAMES=$(echo "$SCAN_JSON" | python3 -c "import json,sys; print(', '.join(json.load(sys.stdin).keys()))" 2>/dev/null)
    ok "$DEVICE_COUNT Gerät(e) gefunden: $NAMES"
else
    fail "Kein Chromecast per mDNS gefunden"
    hint "mDNS/UDP 5353 wird oft von Firewalls/VLANs geblockt — Gerät und Rechner müssen im selben Broadcast-Segment sein"
    hint "systemctl status avahi-daemon prüfen, falls Zeroconf lokal nicht läuft"
fi

if [[ -z "$HOST" ]]; then
    echo
    echo "Keine Geräte-IP angegeben — Port-Check übersprungen (Aufruf: $0 <chromecast-ip>)."
    exit 0
fi

# 3. Cast control port reachable directly (bypasses discovery entirely,
# isolates "found via mDNS" from "can actually connect and cast").
echo
if timeout 3 bash -c "echo > /dev/tcp/$HOST/8009" 2>/dev/null; then
    ok "Cast-Port 8009 auf $HOST erreichbar"
else
    fail "Cast-Port 8009 auf $HOST NICHT erreichbar"
    hint "Firewall auf diesem Rechner/im Netzwerk prüfen, oder Gerät hängt in einem anderen VLAN"
fi

echo
echo "Fertig."
