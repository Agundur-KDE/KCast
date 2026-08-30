#!/usr/bin/env bash
# Checks the prerequisites KCast needs, before you go looking for a bug in
# the widget itself: catt installed, firewalld rules (if firewalld is the
# active firewall), a Chromecast actually discoverable (mDNS), and the Cast
# control port reachable if you have a device IP handy.

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
hint() { echo -e "    ${YELLOW}→${NC} $1"; }

HOST="${1:-}"

echo "KCast Setup Check"
echo

# 1. catt installed
if command -v catt >/dev/null 2>&1; then
    ok "catt found ($(command -v catt))"
else
    fail "catt not installed"
    hint "pip install catt  (or your distro's package, if it has one)"
    exit 1
fi

# 2. firewalld rules — the exact checks the README's firewall-cmd block
# sets up: mDNS service, Cast-Control port, and the local-file HTTP
# server's port range. Skipped entirely if firewalld isn't the active
# firewall (nftables/ufw/none) — a false negative here would be worse
# than no answer, see [[feedback_setup_test_single_cause_hint]].
echo
if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
    FW_SERVICES=$(firewall-cmd --list-services 2>/dev/null)
    FW_PORTS=$(firewall-cmd --list-ports 2>/dev/null)

    if grep -qw "mdns" <<<"$FW_SERVICES"; then
        ok "firewalld: mdns service allowed"
    else
        fail "firewalld: mdns service NOT allowed"
        hint "sudo firewall-cmd --permanent --add-service=mdns && sudo firewall-cmd --reload"
    fi

    if grep -qw "8009/tcp" <<<"$FW_PORTS"; then
        ok "firewalld: port 8009/tcp allowed"
    else
        fail "firewalld: port 8009/tcp NOT allowed"
        hint "sudo firewall-cmd --permanent --add-port=8009/tcp && sudo firewall-cmd --reload"
    fi

    if grep -qw "45000-47000/tcp" <<<"$FW_PORTS"; then
        ok "firewalld: port range 45000-47000/tcp allowed (for casting local files)"
    else
        fail "firewalld: port range 45000-47000/tcp NOT allowed"
        hint "only needed for casting LOCAL files (catt spins up its own HTTP server for that)"
        hint "sudo firewall-cmd --permanent --add-port=45000-47000/tcp && sudo firewall-cmd --reload"
    fi
else
    echo "firewalld not active/installed — firewall check skipped (different firewall? check manually)."
fi

# 3. mDNS/Zeroconf discovery actually finds a device — the real
# end-to-end check, catches firewall/multicast/VLAN issues in one go.
#
# `catt scan -j` can also just crash (seen in the wild: a catt/pychromecast
# version mismatch made `d._asdict()` raise AttributeError on every scan).
# That used to look identical to "no device found" here because stderr was
# discarded — a crash got silently misreported as a network problem, see
# [[feedback_setup_test_single_cause_hint]]. Capture stderr/exit code
# separately so a crash is reported as what it is, not as "not found".
echo
echo "Scanning network (catt scan, ~5s)…"
SCAN_STDERR=$(mktemp)
SCAN_JSON=$(timeout 10 catt scan -j 2>"$SCAN_STDERR")
SCAN_EXIT=$?
DEVICE_COUNT=$(echo "$SCAN_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo 0)

if [[ "$DEVICE_COUNT" -gt 0 ]]; then
    NAMES=$(echo "$SCAN_JSON" | python3 -c "import json,sys; print(', '.join(json.load(sys.stdin).keys()))" 2>/dev/null)
    ok "$DEVICE_COUNT device(s) found: $NAMES"
elif [[ "$SCAN_EXIT" -ne 0 || -s "$SCAN_STDERR" ]]; then
    fail "catt scan -j crashed instead of finding nothing"
    hint "this is a catt/pychromecast bug, not a network problem — plain 'catt scan' (no -j) may still work"
    hint "raw error (last lines):"
    sed 's/^/        /' "$SCAN_STDERR" | tail -5
    hint "please report this at https://github.com/skorokithakis/catt/issues with the full traceback above"
else
    fail "No Chromecast found via mDNS"
    hint "mDNS/UDP 5353 is often blocked by firewalls/VLANs — device and PC must be on the same broadcast segment"
    hint "check systemctl status avahi-daemon if Zeroconf isn't running locally"
fi
rm -f "$SCAN_STDERR"

if [[ -z "$HOST" ]]; then
    echo
    echo "No device IP given — port check skipped (usage: $0 <chromecast-ip>)."
    exit 0
fi

# 4. Cast control port reachable directly (bypasses discovery entirely,
# isolates "found via mDNS" from "can actually connect and cast").
echo
if timeout 3 bash -c "echo > /dev/tcp/$HOST/8009" 2>/dev/null; then
    ok "Cast port 8009 on $HOST reachable"
else
    fail "Cast port 8009 on $HOST NOT reachable"
    hint "check the firewall on this machine/network, or the device is on a different VLAN"
fi

echo
echo "Done."
