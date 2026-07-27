#!/usr/bin/env bash
#
# setup-battery-care.sh — install charge-mode control for the Yoga Slim 7 14AGP11.
#
# Stock, this laptop charges with Lenovo "Rapid Charge" ON: ~44 W into a 70 Wh
# cell (~0.63C), which is hot and hard on the battery. The EC can do better, via
# one sysfs knob (`charge_types`) with three settings — Fast / Standard /
# Long_Life. See battery-care.sh for what each one means.
#
# This installs, in one go:
#   1. /usr/local/bin/battery-care          the CLI (battery-care.sh)
#   2. /etc/udev/rules.d/99-battery-care.rules
#        - makes charge_types writable by the '$GROUP' group, so the panel
#          indicator needs no root and no password prompt
#        - re-applies your chosen mode at boot and after an AC plug/unplug,
#          which the EC can otherwise forget
#   3. ~/.local/bin/battery-care-indicator.py + an autostart entry
#        a notification-area indicator showing the current mode and live
#        charge rate, with a menu to switch between the three modes
#
#   sudo ./scripts/setup-battery-care.sh                 # install, select Standard
#   sudo ./scripts/setup-battery-care.sh conservation    # install, select Long_Life
#   sudo ./scripts/setup-battery-care.sh --uninstall
#
# Reversible: --uninstall removes all of the above and puts the EC back on Fast.
#
# Re-exec under bash if started as `sh setup-battery-care.sh` — dash has no
# $EUID, no arrays and no ${var,,}, and fails with "EUID: parameter not set".
[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"

set -euo pipefail

GROUP=plugdev                 # group granted write access to the knob
RULES=/etc/udev/rules.d/99-battery-care.rules
CLI=/usr/local/bin/battery-care
STATE_DIR=/etc/battery-care
STATE_FILE="$STATE_DIR/mode"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "${1:-}" in
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

# --- Re-run as root if needed (mirrors setup-tty-font.sh) --------------------
if [[ $EUID -ne 0 ]]; then
    echo ">> Elevating with sudo..."
    exec sudo -- "$0" "$@"
fi

# The user we install the indicator + autostart for — not root.
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
[[ -n "$REAL_HOME" && -d "$REAL_HOME" ]] || {
    echo "!! Could not resolve a home directory for '$REAL_USER'." >&2; exit 1; }

AUTOSTART="$REAL_HOME/.config/autostart/battery-care-indicator.desktop"
INDICATOR="$REAL_HOME/.local/bin/battery-care-indicator.py"

# --- Uninstall ----------------------------------------------------------------
if [[ "${1:-}" == "--uninstall" ]]; then
    echo "=== Removing battery-care ==="
    pkill -f battery-care-indicator.py 2>/dev/null || true
    [[ -x "$CLI" ]] && "$CLI" fast >/dev/null 2>&1 || true
    rm -f "$RULES" "$CLI" "$INDICATOR" "$AUTOSTART"
    rm -rf "$STATE_DIR"
    udevadm control --reload
    echo ">> Removed. EC put back on Fast (Rapid Charge), the stock setting."
    exit 0
fi

MODE="${1:-standard}"

echo "=== Battery care: charge-mode control + panel indicator ==="
echo

# --- Sanity: does this kernel/EC expose the knob at all? ---------------------
BAT=""
for d in /sys/class/power_supply/BAT*; do
    [[ -e "$d/charge_types" ]] && { BAT="$d"; break; }
done
if [[ -z "$BAT" ]]; then
    echo "!! No battery exposes 'charge_types'." >&2
    echo "   Needs the ideapad_laptop module and kernel >= 6.14." >&2
    echo "   Check:  lsmod | grep ideapad_laptop" >&2
    exit 1
fi
echo ">> Found the knob: $BAT/charge_types"
echo "   Currently: $(cat "$BAT/charge_types")"
echo

# --- Warn if TLP is also driving the deprecated conservation_mode file -------
# TLP's lenovo plugin writes .../VPC2004:00/conservation_mode, which the kernel
# driver deprecated in favour of charge_types — it is the Long_Life bit under
# another name. If both are configured they fight on every AC transition.
if grep -rqsE '^\s*(START|STOP)_CHARGE_THRESH_BAT' /etc/tlp.conf /etc/tlp.d/ 2>/dev/null; then
    echo "!! WARNING: TLP has charge thresholds configured:"
    grep -rhsE '^\s*(START|STOP)_CHARGE_THRESH_BAT' /etc/tlp.conf /etc/tlp.d/ | sed 's/^/     /'
    echo "   TLP drives the deprecated 'conservation_mode' file and will fight"
    echo "   this indicator on every AC plug/unplug. Comment those out."
    echo
fi

# --- Runtime deps for the indicator ------------------------------------------
MISSING=()
sudo -u "$REAL_USER" python3 - <<'PY' 2>/dev/null || MISSING+=(python3-gi gir1.2-ayatanaappindicator3-0.1)
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("AyatanaAppIndicator3", "0.1")
from gi.repository import Gtk, AyatanaAppIndicator3
PY
if (( ${#MISSING[@]} )); then
    echo ">> Installing indicator dependencies: ${MISSING[*]}"
    apt-get install -y "${MISSING[@]}"
    echo
fi

# --- 1. The CLI ---------------------------------------------------------------
install -m 0755 "$SCRIPT_DIR/battery-care.sh" "$CLI"
echo ">> Installed $CLI"

# --- 2. State directory (the saved mode the udev hook restores) --------------
# The mode file itself must be group-writable, not just the directory: the
# indicator runs as you, and if it can't record a mode switch here then the next
# AC transition silently reverts your choice.
install -d -m 0775 -g "$GROUP" "$STATE_DIR"
printf '%s\n' "$GROUP" > "$STATE_DIR/group"
chmod 0644 "$STATE_DIR/group"
[[ -e "$STATE_FILE" ]] || : > "$STATE_FILE"
chgrp "$GROUP" "$STATE_FILE"
chmod 0664 "$STATE_FILE"
echo ">> Created $STATE_DIR (group $GROUP, group-writable)"

# --- 3. udev rules ------------------------------------------------------------
# Rule 1 grants group write on the sysfs attribute — udev's GROUP=/MODE= only
# apply to device nodes, so the chgrp/chmod goes through the CLI's --udev-perms.
# Rules 2 and 3 restore the saved mode: the EC drops it on some AC transitions,
# and nothing else would put it back.
cat > "$RULES" <<EOF
# Installed by setup-battery-care.sh — charge-mode control for ideapad ECs.
# See scripts/battery-care.sh in the yoga-slim-7-14agp11-linux repo.

# Let the '$GROUP' group write the charge-mode knob (no root for the indicator).
SUBSYSTEM=="power_supply", ACTION=="add|change", ATTR{charge_types}=="?*", \\
  ENV{BATTERY_CARE_GROUP}="$GROUP", RUN+="$CLI --udev-perms"

# Restore the saved mode at boot...
SUBSYSTEM=="power_supply", ACTION=="add", ATTR{charge_types}=="?*", \\
  RUN+="$CLI --udev-reapply"

# ...and after an AC plug/unplug, which can make the EC forget it.
SUBSYSTEM=="power_supply", ACTION=="change", KERNEL=="ACAD", \\
  RUN+="$CLI --udev-reapply"
EOF
echo ">> Installed $RULES"

udevadm control --reload
udevadm trigger --subsystem-match=power_supply
echo ">> udev rules reloaded and triggered"
echo

# --- 4. Select the requested mode --------------------------------------------
"$CLI" "$MODE"
echo

# --- 5. The indicator + autostart --------------------------------------------
install -d -o "$REAL_USER" -g "$REAL_USER" "$REAL_HOME/.local/bin" "$REAL_HOME/.config/autostart"
install -m 0755 -o "$REAL_USER" -g "$REAL_USER" \
    "$SCRIPT_DIR/battery-care-indicator.py" "$INDICATOR"
echo ">> Installed $INDICATOR"

cat > "$AUTOSTART" <<EOF
[Desktop Entry]
Type=Application
Name=Battery Care Indicator
Comment=Charge mode (Fast / Standard / Long Life) in the notification area
Exec=$INDICATOR
Icon=battery-good-charging-symbolic
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
chown "$REAL_USER:$REAL_USER" "$AUTOSTART"
echo ">> Installed $AUTOSTART (starts at login)"

# Start it now so the icon appears without logging out.
pkill -u "$REAL_USER" -f battery-care-indicator.py 2>/dev/null || true
sudo -u "$REAL_USER" env DISPLAY="${DISPLAY:-:0}" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$REAL_USER")/bus" \
    setsid "$INDICATOR" >/dev/null 2>&1 < /dev/null &
echo ">> Indicator started"
echo

echo "=== Done. ==="
"$CLI" status
echo
echo "   The icon is in the notification area — click it to switch modes."
echo "   From the shell:  battery-care status | fast | standard | conservation"
echo "   Watch the effect on the charge rate:  battery-care watch"
echo "   Remove everything:  sudo $0 --uninstall"
