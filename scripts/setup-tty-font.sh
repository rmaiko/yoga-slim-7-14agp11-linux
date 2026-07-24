#!/usr/bin/env bash
#
# setup-tty-font.sh — make the text consoles (Ctrl+Alt+F3 … F6) readable on the
# 2.8K OLED. At 2880x1800 the default ~8x16 console font renders as microscopic
# text — the login/recovery TTYs and early-boot kernel messages are unreadable.
#
# This sets a large **DejaVu** console font and — the part people miss — bakes it
# into the **initramfs**, so it applies from early boot, not just after the
# desktop's console-setup service eventually runs.
#
# What it changes: FONTFACE / FONTSIZE in /etc/default/console-setup (backed up),
# then `setupcon` (apply now) + `update-initramfs -u` (persist to early boot).
# Nothing else. Fully reversible (restore the backup, re-run those two commands).
#
#   sudo ./scripts/setup-tty-font.sh              # DejaVu 24x43 (good default @ 2.8K)
#   sudo ./scripts/setup-tty-font.sh 32x59        # bigger
#   ./scripts/setup-tty-font.sh --list            # list available DejaVu sizes
#   ./scripts/setup-tty-font.sh --show            # show current config
#
set -euo pipefail

FACE="DejaVu"
CS=/etc/default/console-setup
FONTDIR=/usr/share/consolefonts

# --- List available DejaVu sizes (as WIDTHxHEIGHT, the FONTSIZE order) ---------
# console-setup names files <charset>-DejaVu<HEIGHT>x<WIDTH>.psf.gz, but the
# FONTSIZE variable is WIDTHxHEIGHT — so we reverse the two numbers here.
list_sizes() {
    ls "$FONTDIR"/*-"$FACE"[0-9]*x[0-9]*.psf.gz 2>/dev/null \
        | sed -E "s#.*-${FACE}([0-9]+)x([0-9]+)\.psf\.gz#\2x\1#" \
        | sort -t x -k2 -n -u
}

case "${1:-}" in
    --list)
        echo "Available ${FACE} console sizes (WIDTHxHEIGHT), smallest→largest:"
        list_sizes | sed 's/^/  /'
        echo
        echo "At 2880x1800: 24x43 ≈ 120 cols × 41 rows, 32x59 ≈ 90 × 30 (bigger)."
        exit 0 ;;
    --show)
        echo "Current console-setup ($CS):"
        grep -E '^(FONTFACE|FONTSIZE)=' "$CS" 2>/dev/null || echo "  (no FONTFACE/FONTSIZE set)"
        exit 0 ;;
    -h|--help)
        sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

SIZE="${1:-24x43}"

# --- Validate the requested size against what's actually installed ------------
W="${SIZE%x*}"; H="${SIZE#*x}"
if [[ ! "$SIZE" =~ ^[0-9]+x[0-9]+$ ]]; then
    echo "!! Size must look like WIDTHxHEIGHT, e.g. 24x43." >&2; exit 1
fi
if ! ls "$FONTDIR"/*-"${FACE}${H}x${W}".psf.gz >/dev/null 2>&1; then
    echo "!! No ${FACE} font for size ${SIZE}. Run: $0 --list" >&2
    exit 1
fi

# --- Re-run as root if needed (mirrors fix-amdgpu-freeze.sh) ------------------
if [[ $EUID -ne 0 ]]; then
    echo ">> Elevating with sudo..."
    exec sudo -- "$0" "$@"
fi

echo "=== TTY console font: ${FACE} ${SIZE} ==="
echo

# --- Back up console-setup ----------------------------------------------------
BACKUP="${CS}.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$CS" "$BACKUP"
echo ">> Backed up $CS -> $BACKUP"

# --- Set FONTFACE / FONTSIZE (idempotent) ------------------------------------
set_kv() { # key value
    if grep -qE "^$1=" "$CS"; then
        sed -i "s|^$1=.*|$1=\"$2\"|" "$CS"
    else
        printf '%s="%s"\n' "$1" "$2" >> "$CS"
    fi
}
set_kv FONTFACE "$FACE"
set_kv FONTSIZE "$SIZE"
echo ">> Set: $(grep -E '^(FONTFACE|FONTSIZE)=' "$CS" | tr '\n' ' ')"
echo

# --- Apply now to the virtual consoles ---------------------------------------
echo ">> Applying to the consoles now (setupcon)..."
setupcon --force 2>/dev/null || setupcon || echo "   (setupcon will apply on next VT switch/login)"
echo

# --- Persist into the initramfs so early boot uses it too --------------------
echo ">> Baking the font into the initramfs (update-initramfs -u)..."
update-initramfs -u
echo

echo "=== Done. ==="
echo "   Check it: switch to a console with Ctrl+Alt+F3 (back to the desktop"
echo "   with Ctrl+Alt+F2 or F1). Text should now be large and legible."
echo "   Try a bigger size any time:  sudo $0 32x59      (see --list)"
echo "   Revert:  sudo cp $BACKUP $CS && sudo setupcon && sudo update-initramfs -u"
