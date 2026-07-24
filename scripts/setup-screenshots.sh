#!/usr/bin/env bash
# setup-screenshots.sh — macOS-style region screenshots on XFCE.
#
#   Print              -> drag a region  -> saved PNG in ~/Pictures/Screenshots
#   Ctrl+Print         -> drag a region  -> clipboard
#   Ctrl+Shift+Print   -> fullscreen     -> saved PNG (Print no longer does this)
#
# Uses xfce4-screenshooter (region select + clipboard + silent auto-save are all
# built in). IMPORTANT: on X11 an image copied to the clipboard is LOST the moment
# the copying tool exits unless a clipboard manager holds it — so this also ensures
# xfce4-clipman is running. See the repo README (Screenshots section).
set -euo pipefail

command -v xfconf-query >/dev/null || { echo "xfconf-query not found — this targets XFCE." >&2; exit 1; }
command -v xfce4-screenshooter >/dev/null || { echo "Install xfce4-screenshooter first." >&2; exit 1; }

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"

bind() { # key command
  xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$1" -n -t string -s "$2" 2>/dev/null \
    || xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$1" -s "$2"
  echo ">> $1 -> $2"
}

bind "Print"                   "xfce4-screenshooter -r -s $DIR"
bind "<Primary>Print"          "xfce4-screenshooter -r -c"
bind "<Primary><Shift>Print"   "xfce4-screenshooter -f -s $DIR"

# Ensure a clipboard manager is running so Ctrl+Print actually persists.
if command -v xfce4-clipman >/dev/null; then
  if ! pgrep -x xfce4-clipman >/dev/null; then
    (setsid xfce4-clipman >/dev/null 2>&1 < /dev/null &) || true
    sleep 1
  fi
  pgrep -x xfce4-clipman >/dev/null \
    && echo ">> xfce4-clipman running (clipboard screenshots will persist)" \
    || echo "!! could not start xfce4-clipman — Ctrl+Print may paste nothing"
else
  echo "!! xfce4-clipman not installed — Ctrl+Print (clipboard) will be unreliable."
  echo "   Install it (sudo apt install xfce4-clipman) or use another clipboard manager."
fi

echo
echo "Done. Saved screenshots go to: $DIR"
