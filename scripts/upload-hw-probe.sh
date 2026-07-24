#!/usr/bin/env bash
#
# upload-hw-probe.sh — optionally share an ANONYMIZED hardware probe with the
# Linux Hardware Database (https://linux-hardware.org) to help the next person
# discover that this laptop runs Linux.
#
# Why: linux-hardware.org pages rank well in search for obscure/new models, so a
# probe for the Yoga Slim 7 14AGP11 (83QS) helps others find that it works —
# complementing this repo's write-up. It's a community database (BSD-licensed
# project); uploading is a small, kind thing to do, but entirely your choice.
#
# Privacy (per hw-probe's own docs): private information — username, hostname, IP
# addresses, MAC addresses, UUIDs and serial numbers — is **NOT** uploaded. Only
# a salted SHA-512 hash prefix of MACs/serials (formatted like UUIDs) goes up, over
# HTTPS. This script still lets you INSPECT the probe locally before uploading.
#
# This script only acts when you say yes at each prompt. It will offer to install
# hw-probe if it's missing, let you review the probe, then upload on confirmation.
#
#   ./scripts/upload-hw-probe.sh            # interactive: install? review? upload?
#   ./scripts/upload-hw-probe.sh --help
#
set -euo pipefail

# --- Prompt helper: returns 0 for yes. Second arg is the default (Y or N). ----
confirm() {
    local prompt="$1" default="${2:-N}" ans=""
    read -r -p "$prompt " ans || ans=""
    ans="${ans:-$default}"
    [[ "$ans" =~ ^[Yy] ]]
}

case "${1:-}" in
    # Print the header comment block (line 2 until the first non-comment line).
    -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
esac

cat <<'INTRO'
=== Share an anonymized hardware probe (linux-hardware.org) ===

This uploads an ANONYMIZED probe of this machine to the Linux Hardware Database
to help other people find that this laptop works on Linux.

  • NOT uploaded: hostname, usernames, IPs, MAC addresses, UUIDs, serial numbers.
  • Uploaded: detected devices, kernel modules/drivers, and their working status,
    plus salted hash prefixes (as UUIDs) of MACs/serials. Over HTTPS.
  • You'll get a public probe URL you can add to this repo's README.

You can inspect the probe locally before anything is uploaded.
INTRO
echo
if ! confirm "Continue? [y/N]" N; then
    echo ">> No worries — nothing was done."
    exit 0
fi
echo

# --- Ensure hw-probe is installed (offer to install if not) -------------------
if ! command -v hw-probe >/dev/null 2>&1; then
    echo ">> hw-probe is not installed."
    if command -v apt-get >/dev/null 2>&1 && apt-cache policy hw-probe 2>/dev/null | grep -qE 'Candidate: [0-9]'; then
        if confirm "Install it with apt (sudo apt install hw-probe)? [Y/n]" Y; then
            sudo apt-get update && sudo apt-get install -y hw-probe
        else
            echo ">> Skipping install. Aborting."; exit 0
        fi
    elif command -v snap >/dev/null 2>&1; then
        if confirm "Install it as a snap (sudo snap install hw-probe)? [Y/n]" Y; then
            sudo snap install hw-probe
        else
            echo ">> Skipping install. Aborting."; exit 0
        fi
    else
        echo "!! No apt/snap candidate found. Install hw-probe manually:" >&2
        echo "   https://github.com/linuxhw/hw-probe#install" >&2
        exit 1
    fi
    echo
fi
echo ">> Using $(command -v hw-probe) ($(hw-probe -help 2>&1 | grep -m1 -oE 'hw-probe [0-9.]+' || echo installed))"
echo

# --- Optional: build the probe locally and let the user inspect it ------------
# hw-probe needs root to read all hardware. -save writes the probe package to DIR.
if confirm "Build the probe and review it locally BEFORE uploading? [Y/n]" Y; then
    DIR="$(mktemp -d "${TMPDIR:-/tmp}/hwprobe.XXXXXX")"
    echo ">> Building probe into $DIR (needs sudo to read hardware)..."
    sudo hw-probe -all -save "$DIR"
    echo
    echo ">> Probe saved. Inspect what would be uploaded, e.g.:"
    echo "     ls -R \"$DIR\""
    echo "     less \"$DIR\"/*/devices \"$DIR\"/*/host   2>/dev/null"
    echo "   (Remember: serials/MACs/UUIDs are hashed, not sent in the clear.)"
    echo
    if ! confirm "Looks good — upload it now? [y/N]" N; then
        echo ">> Not uploading. Your local probe is in: $DIR"
        exit 0
    fi
else
    if ! confirm "Upload an anonymized probe now? [y/N]" N; then
        echo ">> Not uploading. Nothing was sent."
        exit 0
    fi
fi
echo

# --- Upload ------------------------------------------------------------------
echo ">> Uploading (sudo hw-probe -all -upload)..."
LOG="$(mktemp "${TMPDIR:-/tmp}/hwprobe-upload.XXXXXX.log")"
set +e
sudo hw-probe -all -upload 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}
set -e
echo

URL="$(grep -oiE 'https://[a-z.-]*linux-hardware\.org/[^ ]*probe=[A-Za-z0-9]+' "$LOG" | head -1 || true)"
if [[ $rc -eq 0 && -n "$URL" ]]; then
    echo "=== Uploaded. Thank you for helping the community! ==="
    echo "   Your probe URL:"
    echo "     $URL"
    echo
    echo "   Consider adding it to the README so people who find this repo can"
    echo "   cross-check their unit against a real probe of this model."
else
    echo "!! Upload did not clearly succeed (exit $rc). See the log above / $LOG"
    echo "   You can retry later, or upload a saved probe with: hw-probe -src DIR -upload"
    exit 1
fi
rm -f "$LOG"
