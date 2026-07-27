#!/usr/bin/env bash
#
# battery-care.sh — read and set the EC charge mode on the Yoga Slim 7 14AGP11.
#
# This laptop ships with Lenovo "Rapid Charge" ON, pushing ~44 W into a 70 Wh
# cell — about 0.63C. The ideapad_laptop driver exposes ONE knob covering all of
# Lenovo's battery-care behaviour:
#
#     /sys/class/power_supply/BAT1/charge_types  ->  [Fast] Standard Long_Life
#
#   Fast        Rapid Charge ON. Charges to 100%. Stock default.
#   Standard    Rapid Charge OFF. Charges to 100%.
#   Long_Life   Conservation mode. Stops around 55-60% and holds there. Best
#               for a machine that mostly lives on AC.
#
# MEASURED on this unit (25-28% SoC): Fast 44.4 W, Standard 44.2 W, Long_Life
# 43.9 W. This knob does NOT throttle the charge rate — the rate is bounded by
# the USB-PD contract (3 A ~= 60 W negotiated) minus system draw (~15 W). There
# is no software rate limiter; a lower-wattage PD charger is the only lever on
# rate. What Long_Life buys you is not slower charging but never parking the
# cell at 100%, which is what drives calendar aging.
#
# NOTE the older /sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode
# file is DEPRECATED by the kernel driver itself ("conservation_mode attribute
# has been deprecated, see charge_types") and is just the Long_Life bit under
# another name. TLP's lenovo plugin still drives that old file, so do NOT set
# START/STOP_CHARGE_THRESH_BAT* in tlp.conf as well — the two will fight.
#
#   battery-care.sh                  # show current mode, charge rate, health
#   battery-care.sh fast             # 100%, rapid  (~44 W)
#   battery-care.sh standard         # 100%, normal rate
#   battery-care.sh conservation     # ~60% cap     (alias: long-life)
#   battery-care.sh watch            # live charge rate, 1 Hz, until Ctrl-C
#
# Writing needs root, OR the group-write permission that setup-battery-care.sh
# installs — that setup also makes the choice survive reboot and AC unplug, and
# adds the panel indicator.
#
set -euo pipefail

STATE_DIR=/etc/battery-care
STATE_FILE="$STATE_DIR/mode"
GROUP_FILE="$STATE_DIR/group"

# The group setup-battery-care.sh granted write access to. Recorded at install
# time so the CLI, the udev hook and the indicator all agree on it.
care_group() {
    if [[ -r "$GROUP_FILE" ]]; then cat "$GROUP_FILE"
    else echo "${BATTERY_CARE_GROUP:-plugdev}"; fi
}

# --- Locate the battery that actually carries the knob ------------------------
find_bat() {
    local d
    for d in /sys/class/power_supply/BAT*; do
        [[ -e "$d/charge_types" ]] && { echo "$d"; return 0; }
    done
    return 1
}

BAT="$(find_bat)" || {
    echo "!! No battery exposing 'charge_types' found." >&2
    echo "   Needs the ideapad_laptop module and a kernel with charge_types" >&2
    echo "   support (>= 6.14). Check: lsmod | grep ideapad_laptop" >&2
    exit 1
}

# charge_types reads as e.g. "[Fast] Standard Long_Life" — pull out the bracketed one.
current_mode() { sed -n 's/.*\[\([A-Za-z_]*\)\].*/\1/p' "$BAT/charge_types"; }

# Everything the file offers, brackets stripped — used to validate before writing.
available_modes() { tr -d '[]' < "$BAT/charge_types"; }

# --- Friendly name <-> sysfs value -------------------------------------------
to_sysfs() {
    case "${1,,}" in
        fast|rapid)                     echo Fast ;;
        standard|normal)                echo Standard ;;
        conservation|long-life|longlife|long_life) echo Long_Life ;;
        *) return 1 ;;
    esac
}

describe() {
    case "$1" in
        Fast)      echo "Rapid Charge — to 100% (stock)" ;;
        Standard)  echo "Rapid Charge off — to 100%" ;;
        Long_Life) echo "Conservation — stops around 55-60%" ;;
        *)         echo "unknown" ;;
    esac
}

# --- Status -------------------------------------------------------------------
# power_now is charge rate while charging and drain while discharging; energy_*
# are in µWh, power_now in µW.
read_int() { cat "$1" 2>/dev/null || echo 0; }

show_status() {
    local mode cap st pw ef ed cyc health
    mode="$(current_mode)"
    cap="$(read_int "$BAT/capacity")"
    st="$(cat "$BAT/status" 2>/dev/null || echo unknown)"
    pw="$(read_int "$BAT/power_now")"
    ef="$(read_int "$BAT/energy_full")"
    ed="$(read_int "$BAT/energy_full_design")"
    cyc="$(read_int "$BAT/cycle_count")"

    printf 'Mode      : %s   (%s)\n' "$mode" "$(describe "$mode")"
    printf 'Battery   : %s%%  %s\n' "$cap" "$st"
    printf 'Rate      : %.1f W' "$(echo "$pw" | awk '{print $1/1000000}')"
    case "$st" in
        Charging)    printf '  (into the battery)\n' ;;
        Discharging) printf '  (system draw)\n' ;;
        *)           printf '\n' ;;
    esac
    if (( ed > 0 )); then
        health=$(awk -v f="$ef" -v d="$ed" 'BEGIN{printf "%.1f", 100*f/d}')
        printf 'Health    : %.1f / %.1f Wh  (%s%%), %s cycles\n' \
            "$(echo "$ef" | awk '{print $1/1000000}')" \
            "$(echo "$ed" | awk '{print $1/1000000}')" "$health" "$cyc"
    fi
    printf 'Available : %s\n' "$(available_modes)"
    [[ -r "$STATE_FILE" ]] && printf 'Saved     : %s  (re-applied on boot / AC change)\n' "$(cat "$STATE_FILE")"
    return 0
}

# --- Apply --------------------------------------------------------------------
set_mode() {
    local want="$1" now
    now="$(current_mode)"

    if ! grep -qw -- "$want" <<<"$(available_modes)"; then
        echo "!! '$want' is not offered by this EC. Available: $(available_modes)" >&2
        exit 1
    fi

    if [[ "$now" == "$want" ]]; then
        echo ">> Already $want — nothing to do."
    elif [[ -w "$BAT/charge_types" ]]; then
        echo "$want" > "$BAT/charge_types"
    elif [[ $EUID -ne 0 ]]; then
        echo ">> $BAT/charge_types is not writable by you; elevating with sudo..."
        echo ">> (run setup-battery-care.sh once to drop the sudo requirement)"
        exec sudo -- "$0" "$want"
    else
        echo "!! Cannot write $BAT/charge_types even as root." >&2
        exit 1
    fi

    now="$(current_mode)"
    if [[ "$now" != "$want" ]]; then
        echo "!! Wrote '$want' but the EC reports '$now' — it refused the change." >&2
        exit 1
    fi

    # Remember it so the udev hook can restore it after a reboot / AC unplug.
    # The file must stay group-writable, or the indicator (which runs as you,
    # not root) silently fails to record your choice and the next AC transition
    # reverts it.
    if [[ -w "$STATE_FILE" ]] || { [[ ! -e "$STATE_FILE" ]] && [[ -w "$STATE_DIR" ]]; }; then
        echo "$want" > "$STATE_FILE"
        if [[ $EUID -eq 0 ]]; then
            chgrp "$(care_group)" "$STATE_FILE" 2>/dev/null || true
            chmod 0664 "$STATE_FILE" 2>/dev/null || true
        fi
    elif [[ -d "$STATE_DIR" ]]; then
        echo "!! Applied, but could not update $STATE_FILE — this mode will NOT" >&2
        echo "   survive a reboot or AC unplug. Re-run setup-battery-care.sh." >&2
    fi

    echo ">> Mode: $now — $(describe "$now")"
    if [[ "$now" == Long_Life && "$(cat "$BAT/capacity")" -lt 55 ]]; then
        echo "   Below the cap, so it keeps charging (at the usual ~44 W — this"
        echo "   mode sets a stop point, not a rate) until it reaches ~60%."
    fi
}

# --- udev hooks (installed by setup-battery-care.sh) --------------------------
# Kept in this one script so there is a single file to install and audit.
udev_perms() {
    # Make the knob group-writable so the panel indicator needs no root.
    local grp; grp="$(care_group)"
    chgrp "$grp" "$BAT/charge_types" 2>/dev/null || true
    chmod g+w    "$BAT/charge_types" 2>/dev/null || true
    # Same for the saved-mode file, so the indicator can record your choice.
    [[ -e "$STATE_FILE" ]] || return 0
    chgrp "$grp" "$STATE_FILE" 2>/dev/null || true
    chmod 0664   "$STATE_FILE" 2>/dev/null || true
}

udev_reapply() {
    # The EC can drop the setting across an AC transition; put it back.
    [[ -r "$STATE_FILE" ]] || return 0
    local want; want="$(cat "$STATE_FILE")"
    [[ -n "$want" && "$want" != "$(current_mode)" ]] || return 0
    echo "$want" > "$BAT/charge_types" 2>/dev/null || true
}

# --- Dispatch -----------------------------------------------------------------
case "${1:-status}" in
    status|--status|-s) show_status ;;
    watch|--watch|-w)
        echo "Live charge rate — Ctrl-C to stop.  Mode: $(current_mode)"
        while :; do
            printf '\r  %s  %s%%  %6.2f W   ' \
                "$(cat "$BAT/status")" "$(cat "$BAT/capacity")" \
                "$(awk '{print $1/1000000}' "$BAT/power_now")"
            sleep 1
        done ;;
    --udev-perms)   udev_perms ;;
    --udev-reapply) udev_reapply ;;
    -h|--help)      sed -n '2,37p' "$0" | sed 's/^# \{0,1\}//' ;;
    *)
        want="$(to_sysfs "$1")" || {
            echo "!! Unknown mode '$1'. Use: fast | standard | conservation" >&2
            echo "   ('$0 --help' for what each one does)" >&2
            exit 1
        }
        set_mode "$want" ;;
esac
