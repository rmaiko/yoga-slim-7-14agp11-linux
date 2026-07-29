#!/usr/bin/env python3
"""battery-care-indicator — panel indicator for the EC charge mode.

Sits in the XFCE notification area, shows which charge mode the EC is in (and
the live charge rate while plugged in), and lets you switch between them from
the menu:

    Fast        Rapid Charge, to 100% at ~44 W   (stock, hardest on the cell)
    Standard    to 100% at the normal rate
    Long_Life   conservation, stops around 80%

All three are the one `charge_types` sysfs knob on the battery — see
battery-care.sh for the full explanation. Switching needs write access to that
file; setup-battery-care.sh installs a udev rule that grants it to your group,
so no root and no password prompt per click. Without that rule this falls back
to `pkexec battery-care <mode>`.

Run setup-battery-care.sh to install this and start it at login.
"""

import glob
import os
import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("AyatanaAppIndicator3", "0.1")
from gi.repository import AyatanaAppIndicator3 as AppIndicator  # noqa: E402
from gi.repository import GLib, Gtk  # noqa: E402

REFRESH_SECONDS = 4
STATE_FILE = "/etc/battery-care/mode"

# sysfs value -> (menu label, tooltip/description, icon candidates best-first)
#
# The icons are deliberately NOT batteries: this sits next to the normal battery
# indicator, and a second battery there says nothing. The power-profile-* set
# (speedometer / balance scale / leaf) reads as "which mode", which is the only
# thing this icon has to say. They live in Adwaita; GTK falls back to it even
# under other themes, but the battery names stay as a last resort for systems
# where they don't resolve.
MODES = {
    "Fast": (
        "Fast charge — to 100%",
        "Lenovo Rapid Charge. Charges to 100%. Stock default.",
        ("power-profile-performance-symbolic", "battery-full-charging-symbolic"),
    ),
    "Standard": (
        "Standard — to 100%",
        "Rapid Charge off. Charges to 100%. Measured no slower than Fast on "
        "this machine — the rate is set by the USB-PD contract, not this knob.",
        ("power-profile-balanced-symbolic", "battery-good-symbolic"),
    ),
    "Long_Life": (
        "Long Life — stop at ~80%",
        "Conservation mode. Holds the charge around 80% — best when the "
        "laptop mostly lives on AC, and the only one of the three that "
        "measurably helps battery life.",
        ("power-profile-power-saver-symbolic", "battery-level-80-symbolic"),
    ),
}


def find_battery():
    """The battery carrying the charge_types knob (BAT1 on this machine)."""
    for path in sorted(glob.glob("/sys/class/power_supply/BAT*")):
        if os.path.exists(os.path.join(path, "charge_types")):
            return path
    return None


BAT = find_battery()
if BAT is None:
    print(
        "No battery exposing 'charge_types' — needs ideapad_laptop and a "
        "kernel >= 6.14. Nothing to indicate; exiting.",
        file=sys.stderr,
    )
    sys.exit(1)


def read(name, default=""):
    try:
        with open(os.path.join(BAT, name)) as fh:
            return fh.read().strip()
    except OSError:
        return default


def read_watts(name):
    """µW -> W, 0.0 if the file is missing or unreadable."""
    try:
        return int(read(name, "0")) / 1_000_000
    except ValueError:
        return 0.0


def current_mode():
    """charge_types reads as '[Fast] Standard Long_Life' — return the bracketed one."""
    for token in read("charge_types").split():
        if token.startswith("[") and token.endswith("]"):
            return token[1:-1]
    return ""


def available_modes():
    return [t.strip("[]") for t in read("charge_types").split()]


def apply_mode(mode):
    """Write the mode.

    Returns (ok, message). ok=False means the EC is unchanged. ok=True with a
    message means the mode is live but something needs attention.
    """
    path = os.path.join(BAT, "charge_types")
    try:
        with open(path, "w") as fh:
            fh.write(mode)
    except PermissionError:
        # No udev rule installed — ask politely, once, via polkit.
        try:
            subprocess.run(
                ["pkexec", "battery-care", mode],
                check=True,
                capture_output=True,
                text=True,
            )
        except FileNotFoundError:
            return False, "pkexec not found — run setup-battery-care.sh"
        except subprocess.CalledProcessError as exc:
            return False, (exc.stderr or "").strip() or "permission denied"
    except OSError as exc:
        return False, str(exc)

    if current_mode() != mode:
        return False, f"the EC refused the change (still {current_mode()})"

    # Record it for the udev re-apply hook. NOT cosmetic: if this fails, the
    # next AC plug/unplug restores whatever is still in the file and silently
    # undoes the switch — so report it rather than swallowing it.
    try:
        with open(STATE_FILE, "w") as fh:
            fh.write(mode + "\n")
    except OSError as exc:
        return True, (
            f"Applied now, but {STATE_FILE} is not writable ({exc.strerror}), so "
            "this will be undone on the next reboot or AC unplug. "
            "Re-run setup-battery-care.sh to fix it."
        )
    return True, None


def pick_icon(candidates):
    theme = Gtk.IconTheme.get_default()
    for name in candidates:
        if theme.has_icon(name):
            return name
    return "battery-symbolic"


class BatteryCareIndicator:
    def __init__(self):
        self.suppress = False  # guards programmatic radio updates

        # Start on the current mode's icon — refresh() would fix it a moment
        # later anyway, but not before the panel has shown the wrong one.
        self.indicator = AppIndicator.Indicator.new(
            "battery-care",
            pick_icon(MODES.get(current_mode(), MODES["Fast"])[2]),
            AppIndicator.IndicatorCategory.HARDWARE,
        )
        self.indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE)
        self.indicator.set_title("Battery charge mode")

        self.menu = Gtk.Menu()

        # Live status line, not clickable.
        self.status_item = Gtk.MenuItem(label="…")
        self.status_item.set_sensitive(False)
        self.menu.append(self.status_item)
        self.menu.append(Gtk.SeparatorMenuItem())

        # One radio per mode the EC actually offers.
        self.radios = {}
        group = []
        for mode in ("Fast", "Standard", "Long_Life"):
            if mode not in available_modes():
                continue
            label, tooltip, _ = MODES[mode]
            item = Gtk.RadioMenuItem(label=label)
            item.join_group(group[0] if group else None)
            group.append(item)
            item.set_tooltip_text(tooltip)
            item.connect("toggled", self.on_mode_toggled, mode)
            self.menu.append(item)
            self.radios[mode] = item

        self.menu.append(Gtk.SeparatorMenuItem())

        self.health_item = Gtk.MenuItem(label="…")
        self.health_item.set_sensitive(False)
        self.menu.append(self.health_item)
        self.menu.append(Gtk.SeparatorMenuItem())

        quit_item = Gtk.MenuItem(label="Quit")
        quit_item.connect("activate", lambda *_: Gtk.main_quit())
        self.menu.append(quit_item)

        self.menu.show_all()
        self.indicator.set_menu(self.menu)

        self.refresh()
        GLib.timeout_add_seconds(REFRESH_SECONDS, self.refresh)

    def on_mode_toggled(self, item, mode):
        if self.suppress or not item.get_active():
            return
        label = MODES[mode][0]
        ok, message = apply_mode(mode)
        if not ok:
            self.notify(f"Could not switch to “{label}”", message)
        elif message:
            self.notify(f"Switched to “{label}” — but it won't persist", message)
        self.refresh()

    def notify(self, summary, body):
        """Best-effort desktop notification; falls back to stderr."""
        try:
            subprocess.run(
                ["notify-send", "-i", "battery-caution-symbolic", summary, body],
                check=False,
            )
        except FileNotFoundError:
            print(f"{summary}: {body}", file=sys.stderr)

    def refresh(self):
        mode = current_mode()
        status = read("status", "Unknown")
        capacity = read("capacity", "?")
        watts = read_watts("power_now")

        # Tick the matching radio without re-entering the toggle handler.
        self.suppress = True
        if mode in self.radios and not self.radios[mode].get_active():
            self.radios[mode].set_active(True)
        self.suppress = False

        _, description, icons = MODES.get(mode, ("", "unknown mode", ("battery-symbolic",)))
        self.indicator.set_icon_full(pick_icon(icons), description)

        # Panel label: the charge rate is the number worth watching.
        self.indicator.set_label(
            f"{watts:.0f} W" if status == "Charging" else f"{capacity}%", "100 W"
        )

        rate_note = {
            "Charging": f" · {watts:.1f} W in",
            "Discharging": f" · {watts:.1f} W draw",
        }.get(status, "")
        self.status_item.set_label(f"{capacity}% · {status}{rate_note}")
        self.indicator.set_title(f"Charge mode: {mode or 'unknown'}")

        full = read_watts("energy_full")
        design = read_watts("energy_full_design")
        cycles = read("cycle_count", "?")
        if design:
            self.health_item.set_label(
                f"Health {100 * full / design:.0f}%  "
                f"({full:.1f}/{design:.1f} Wh) · {cycles} cycles"
            )
        else:
            self.health_item.set_label(f"{cycles} cycles")

        return True  # keep the timer alive


if __name__ == "__main__":
    BatteryCareIndicator()
    Gtk.main()
