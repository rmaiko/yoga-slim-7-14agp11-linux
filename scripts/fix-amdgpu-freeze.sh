#!/usr/bin/env bash
#
# fix.sh - Mitigate amdgpu display freeze (frozen screen, live mouse cursor)
#          on Lenovo Yoga 7 (AMD Krackan2 / RDNA 3.5) by disabling PSR and
#          Panel Replay via the amdgpu.dcdebugmask kernel parameter.
#
# Also caps the internal eDP panel at 60Hz (down from 120Hz) via a login
# autostart, as an additional display-engine-load mitigation.
#
# Safe to re-run. Backs up /etc/default/grub before editing. The kernel param
# takes effect after a reboot; the 60Hz cap applies immediately and on every login.
#
set -euo pipefail

PARAM="amdgpu.dcdebugmask=0x410"   # 0x10 = disable PSR, 0x400 = disable Panel Replay
GRUB=/etc/default/grub

# --- Re-run as root if needed ---
if [[ $EUID -ne 0 ]]; then
    echo ">> Elevating with sudo..."
    exec sudo -- "$0" "$@"
fi

echo "=== amdgpu freeze mitigation ==="
echo

# --- Back up grub config ---
BACKUP="${GRUB}.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$GRUB" "$BACKUP"
echo ">> Backed up $GRUB -> $BACKUP"

# --- Set the kernel parameter (idempotent) ---
if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB"; then
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"${PARAM}\"|" "$GRUB"
else
    echo "GRUB_CMDLINE_LINUX_DEFAULT=\"${PARAM}\"" >> "$GRUB"
fi
echo ">> Set: $(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB")"
echo

# --- Regenerate grub ---
echo ">> Running update-grub..."
update-grub
echo

# --- Re-enable Bluetooth (it was never the cause; restore it) ---
echo ">> Re-enabling Bluetooth..."
systemctl enable --now bluetooth 2>/dev/null || echo "   (bluetooth unit unchanged)"
echo

# --- Force internal panel to 60Hz (reduces display-engine load; extra freeze mitigation) ---
# Persistent: an autostart script re-applies 60Hz at every login, with retries so it
# wins even if XFCE's settings daemon tries to restore 120Hz first.
echo ">> Installing 60Hz autostart for the eDP panel..."
USER_NAME="${SUDO_USER:-$(logname 2>/dev/null || true)}"
if [[ -z "$USER_NAME" || "$USER_NAME" == "root" ]]; then
    echo "!! Could not determine the target (non-root) user. Run via: sudo $0" >&2
    exit 1
fi
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
OUTPUT="eDP"
MODE="2880x1800"
RATE="60"

install -d -o "$USER_NAME" -g "$USER_NAME" "$USER_HOME/.local/bin" "$USER_HOME/.config/autostart"

cat > "$USER_HOME/.local/bin/force-60hz.sh" <<EOF
#!/bin/sh
# Force internal panel to ${RATE}Hz. amdgpu display-freeze mitigation.
# Retries so it applies even if it runs before XFCE's display daemon.
i=0
while [ \$i -lt 8 ]; do
    if xrandr --output ${OUTPUT} --mode ${MODE} --rate ${RATE} 2>/dev/null; then
        exit 0
    fi
    i=\$((i+1))
    sleep 1
done
# Fallback: whatever the primary connected output is, at ${RATE}Hz.
OUT=\$(xrandr | awk '/ connected/{print \$1; exit}')
[ -n "\$OUT" ] && xrandr --output "\$OUT" --rate ${RATE} 2>/dev/null || true
EOF
chmod +x "$USER_HOME/.local/bin/force-60hz.sh"
chown "$USER_NAME:$USER_NAME" "$USER_HOME/.local/bin/force-60hz.sh"

cat > "$USER_HOME/.config/autostart/force-60hz.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Force 60Hz (amdgpu freeze mitigation)
Comment=Caps the eDP panel at ${RATE}Hz on login
Exec=${USER_HOME}/.local/bin/force-60hz.sh
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=2
NoDisplay=true
EOF
chown "$USER_NAME:$USER_NAME" "$USER_HOME/.config/autostart/force-60hz.desktop"
echo "   Installed: ~/.local/bin/force-60hz.sh  and  ~/.config/autostart/force-60hz.desktop"

# Apply immediately if an X session is reachable (best-effort; will also apply on next login).
echo ">> Applying 60Hz to the current session (best-effort)..."
XAUTH="$USER_HOME/.Xauthority"
sudo -u "$USER_NAME" env DISPLAY=:0 XAUTHORITY="$XAUTH" \
    xrandr --output "$OUTPUT" --mode "$MODE" --rate "$RATE" 2>/dev/null \
    && echo "   Applied now." || echo "   Could not apply now (no live session) - will apply on next login."
echo

echo "=== Done. The parameter applies on the NEXT boot. ==="
echo "   After rebooting, verify with:"
echo "     cat /proc/cmdline"
echo "     cat /sys/module/amdgpu/parameters/dcdebugmask   # should read 1040"
echo

# --- Offer to reboot ---
read -r -p "Reboot now? [y/N] " ans
case "$ans" in
    [yY]|[yY][eE][sS]) echo ">> Rebooting..."; sleep 1; systemctl reboot ;;
    *) echo ">> Not rebooting. Run 'sudo reboot' when ready." ;;
esac
