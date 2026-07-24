#!/usr/bin/env bash
# brightness-step.sh — perceptual (exponential) backlight stepping for fridolin.
#
# Why this exists: XFCE Power Manager stepped the backlight *linearly* by
# percentage and refused to go below a minimum. On this OLED (raw range
# 0..495000) linear % steps feel enormous when already dim, because perception
# is roughly logarithmic. This script instead walks a precomputed EXPONENTIAL
# curve — many fine steps near the bottom, coarser steps near the top — and can
# reach a true 0 (panel fully dark).
#
# Writes go through systemd-logind's SetBrightness for the *active session*, so
# NO root/sudo is needed and no udev/group changes were made.
# Background & the XFCE key-binding setup: see the repo README (Brightness section)
# and scripts/setup-brightness-keys.sh.
#
# Usage: brightness-step.sh up | down | get | set <percent 0-100>
set -euo pipefail

DEV="amdgpu_bl1"
SYS="/sys/class/backlight/$DEV"
N=30          # number of steps from 0 (off) to max
K=5           # curve steepness; higher = finer at the low end, coarser at top

max=$(cat "$SYS/max_brightness")
cur=$(cat "$SYS/brightness")

# level(i) = round(max * (e^{K*i/N} - 1) / (e^K - 1)), for i in 0..N.
# Emits the whole ladder, one "index value" pair per line.
ladder() {
  awk -v max="$max" -v n="$N" -v k="$K" 'BEGIN{
    d = exp(k) - 1;
    for (i = 0; i <= n; i++) {
      v = max * (exp(k * i / n) - 1) / d;
      printf "%d %d\n", i, int(v + 0.5);
    }
  }'
}

set_raw() {
  local v="$1"
  (( v < 0 )) && v=0
  (( v > max )) && v=$max
  gdbus call --system \
    --dest org.freedesktop.login1 \
    --object-path /org/freedesktop/login1/session/auto \
    --method org.freedesktop.login1.Session.SetBrightness \
    backlight "$DEV" "$v" >/dev/null
  osd "$v"
}

# On-screen bar (replaces the OSD Power Manager used to show). Best-effort.
osd() {
  local v="$1" pct
  pct=$(( (v * 100 + max / 2) / max ))
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -a brightness -t 900 \
      -h "int:value:$pct" \
      -h "string:x-canonical-private-synchronous:brightness" \
      "Brightness  ${pct}%" 2>/dev/null || true
  fi
}

case "${1:-}" in
  up)
    # smallest ladder value strictly greater than current
    next=$(ladder | awk -v c="$cur" '$2 > c {print $2; exit}')
    [ -z "${next:-}" ] && next=$max
    set_raw "$next"
    ;;
  down)
    # largest ladder value strictly less than current (reaches 0)
    next=$(ladder | awk -v c="$cur" '$2 < c {last=$2} END{print last+0}')
    set_raw "$next"
    ;;
  set)
    pct="${2:?usage: set <percent 0-100>}"
    target=$(( max * pct / 100 ))
    set_raw "$target"
    ;;
  get)
    printf '%d / %d  (%d%%)\n' "$cur" "$max" "$(( (cur*100 + max/2) / max ))"
    ;;
  ladder)
    ladder | awk -v max="$max" '{printf "%2d: %7d  (%3d%%)\n",$1,$2,($2*100+max/2)/max}'
    ;;
  *)
    echo "usage: $0 up|down|get|set <pct>|ladder" >&2
    exit 2
    ;;
esac
