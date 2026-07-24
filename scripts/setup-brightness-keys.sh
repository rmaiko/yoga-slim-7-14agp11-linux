#!/usr/bin/env bash
# setup-brightness-keys.sh — install perceptual brightness stepping on XFCE.
#
# What it does (all user-space, NO sudo):
#   1. Installs brightness-step.sh to ~/.local/bin
#   2. Tells XFCE Power Manager to STOP handling the brightness keys (it stepped
#      linearly and refused to reach 0)
#   3. Binds XF86MonBrightnessUp/Down to the perceptual stepper
#
# Writes go through systemd-logind's SetBrightness for the active session, so no
# udev rule / group change / root is needed. See the repo README.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINDIR="$HOME/.local/bin"
DEST="$BINDIR/brightness-step.sh"

command -v xfconf-query >/dev/null || { echo "xfconf-query not found — this targets XFCE." >&2; exit 1; }

mkdir -p "$BINDIR"
install -m 0755 "$SCRIPT_DIR/brightness-step.sh" "$DEST"
echo ">> Installed $DEST"

# Stop Power Manager from grabbing the brightness keys.
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/handle-brightness-keys -n -t bool -s false 2>/dev/null \
  || xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/handle-brightness-keys -s false
echo ">> Power Manager: handle-brightness-keys = false"

# Bind the keys to the stepper.
for pair in "XF86MonBrightnessUp:up" "XF86MonBrightnessDown:down"; do
  key="${pair%%:*}"; dir="${pair##*:}"
  xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$key" -n -t string -s "$DEST $dir" 2>/dev/null \
    || xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$key" -s "$DEST $dir"
  echo ">> Bound $key -> $DEST $dir"
done

# Restart Power Manager so it releases the key grab (best-effort).
if command -v xfce4-power-manager >/dev/null; then
  xfce4-power-manager --quit 2>/dev/null || true
  sleep 1
  (setsid xfce4-power-manager >/dev/null 2>&1 < /dev/null &) || true
fi

echo
echo "Done. Press the brightness keys to test. Tune N/K at the top of $DEST"
echo "then run '$DEST ladder' to preview the steps."
