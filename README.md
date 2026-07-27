# Lenovo Yoga Slim 7 14AGP11 (83QS) on Linux

Setup notes, fixes, and a full hardware/driver reference for running **Linux
(Ubuntu 26.04 / XFCE)** on the **Lenovo Yoga Slim 7 14AGP11** — machine type
**83QS**, the **AMD** variant with the **Ryzen AI 7 445 / Radeon 840M** (Krackan
Point, RDNA 3.5, ISA `gfx1153`) and a **2.8K 120 Hz OLED** panel.

> ⚠️ **Not the 14ILL10.** `14AGP11` (`AGP` = AMD) is a *different machine* from the
> Intel Lunar Lake `Yoga Slim 7 14ILL10`. If you have the AMD one, you're in the
> right place.
>
> <sub>**Landed here from a search?** This page also covers: Yoga Slim 7 14AGP11 /
> 83QS / Gen 9 AMD, Ryzen AI 7 445, Radeon 840M, Krackan Point (Krackan2),
> RDNA 3.5 `gfx1153`, XDNA/`amdxdna` NPU, MediaTek MT7925 Wi-Fi 7, ALC287 audio,
> and the classic symptom **"screen freezes but the mouse still moves" / amdgpu
> display freeze / PSR / Panel Replay** on Ubuntu 26.04 + XFCE.</sub>

This started as one person's "adventures" getting this very new (late-2025)
hardware working on Linux, written up so the next person doesn't have to
rediscover it. Corrections and reports from other units are very welcome — see
[Contributing](#contributing).

---

## TL;DR — does Linux work on it?

**Yes, well** — on a recent kernel (tested **7.0.0-14-generic**, Ubuntu 26.04). One
important fix and a couple of quality-of-life tweaks:

| Area | Status | Notes |
|---|---|---|
| GPU / display | ✅ after fix | **Random display freeze** (frozen screen, live mouse) until PSR/Panel Replay disabled — see below. This is the one thing you *must* do. |
| Wi-Fi 7 (MT7925) | ✅ | `mt7925e`, needs recent `linux-firmware` |
| Bluetooth 5.4 | ✅ | `btusb` |
| Audio (ALC287 + ACP7.0) | ✅ | `snd_hda_intel` / `snd_sof_amd_acp70` |
| Webcam **+ IR** | ✅ | RGB on `/dev/video0`, **IR on `/dev/video2`** — face unlock via Howdy is viable |
| NPU (XDNA) | ✅ | `/dev/accel/accel0` via `amdxdna` |
| Touchpad / hotkeys | ✅ | Synaptics I²C-HID, `ideapad_laptop` |
| Battery / charging | ✅ tweak | Charges at **~44 W into a 70 Wh cell** (PD-bound, not adjustable in software). `charge_types` can cap it at ~60% — see [battery care](#battery-care-stop-charging-at-60--panel-indicator) |
| Fingerprint | ❌ | **No fingerprint hardware exists on this unit** (audited) — don't hunt for a driver |
| Suspend, USB4/TB, NVMe | ✅ | stock |

Full component-by-component detail with PCI/USB IDs and kernel modules:
**[`docs/hardware-reference.md`](docs/hardware-reference.md)**.

---

## The one fix you need: the amdgpu display freeze

**Symptom:** the screen freezes on a stale frame while the **mouse cursor still
moves**; TTYs and the rest of the system stay alive. Happens randomly, and reliably
when a video forces a display-clock switch.

**Cause (confirmed by behaviour):** a stuck panel self-refresh feature (**PSR /
Panel Replay**) wedging the display pipe on this new AMD silicon. Full investigation
and evidence: **[`docs/freeze-diagnosis.md`](docs/freeze-diagnosis.md)**.

**Fix:** disable PSR + Panel Replay via a kernel parameter.

```bash
# Automated (backs up /etc/default/grub, sets the param, re-enables Bluetooth,
# caps the panel at 60 Hz as an extra mitigation, offers to reboot):
sudo ./scripts/fix-amdgpu-freeze.sh
```

Or by hand — add to `GRUB_CMDLINE_LINUX_DEFAULT` in `/etc/default/grub`, then
`sudo update-grub && reboot`:

```
amdgpu.dcdebugmask=0x410      # 0x10 = disable PSR, 0x400 = disable Panel Replay
```

Verify after reboot (should read `1040`):

```bash
cat /sys/module/amdgpu/parameters/dcdebugmask
```

It only turns off a power-saving feature — worst case is marginally worse idle
battery, fully reversible. If it *still* freezes, `docs/freeze-diagnosis.md` has an
escalation path (`0x412`, newer kernel/firmware, `amdgpu.aspm=0`, …).

> **Golden rule for this box:** the silicon is very new AMD (Zen 5 / RDNA 3.5,
> 2025). When something misbehaves, the fix is almost always a **newer kernel +
> newer `linux-firmware`**.

---

## Quality-of-life tweaks (XFCE)

### Finer, macOS-like display brightness (and down to 0)

XFCE Power Manager stepped the OLED backlight *linearly* and wouldn't reach 0, so
low-brightness steps felt huge. This replaces the keys with a **perceptual
(exponential) ladder** — fine steps when dim, coarser when bright, and a true 0 —
writing via logind (no root, no udev):

```bash
./scripts/setup-brightness-keys.sh      # installs the stepper + rebinds the keys
```

See [`scripts/brightness-step.sh`](scripts/brightness-step.sh) (tunable `N` steps /
`K` curve; `brightness-step.sh ladder` previews the stops).

### macOS-style region screenshots

```bash
./scripts/setup-screenshots.sh
```

- **Print** → drag a region → **saved PNG** in `~/Pictures/Screenshots`
- **Ctrl+Print** → drag a region → **clipboard**
- **Ctrl+Shift+Print** → fullscreen → saved PNG

> Gotcha it handles for you: on X11 a screenshot copied to the clipboard vanishes
> when the tool exits unless a clipboard manager holds it, so the script makes sure
> **`xfce4-clipman`** is running.

### Readable text consoles (Ctrl+Alt+F3) on the 2.8K panel

At 2880×1800 the default console font is microscopic — the recovery/login TTYs
and early-boot kernel messages are unreadable. This sets a large **DejaVu**
console font *and bakes it into the initramfs* so it applies from early boot, not
just once the desktop is up:

```bash
sudo ./scripts/setup-tty-font.sh            # DejaVu 24x43 (good default here)
sudo ./scripts/setup-tty-font.sh 32x59      # bigger
./scripts/setup-tty-font.sh --list          # available sizes
```

> The easy-to-miss part: setting `FONTFACE`/`FONTSIZE` in
> `/etc/default/console-setup` alone isn't enough — without
> **`update-initramfs -u`** the font only kicks in late, so boot messages stay
> tiny. The script runs both `setupcon` and `update-initramfs -u` for you.

### Battery care: stop charging at ~60% (+ panel indicator)

Out of the box this machine charges with Lenovo **Rapid Charge** on, pushing
**~44 W into a 70 Wh cell** — about **0.63C**. `ideapad_laptop` exposes Lenovo's
entire battery-care feature set as **one** sysfs knob:

```
/sys/class/power_supply/BAT1/charge_types  ->  [Fast] Standard Long_Life
```

| Mode | Charges to | Measured rate @ 25–28% | Use it when |
|---|---|---|---|
| `Fast` | 100% | 44.4 W | You need a full battery *now*. Stock default. |
| `Standard` | 100% | 44.2 W | Rapid Charge off — but see below: no measurable difference on this unit. |
| `Long_Life` | **~55–60%** | 43.9 W, until the cap | The laptop mostly lives on AC. **The one that actually helps.** |

> ⚠️ **Measured, not assumed — this knob does *not* throttle the charge rate.**
> All three modes charge at the same ~44 W. The rate is set by the **USB-PD
> contract**, not by the EC's charge mode: `ucsi-source-psy-USBC000:002` reports
> `current_now=3000000` (3 A ≈ **60 W** negotiated), the system draws ~15 W, and
> the battery gets the remaining ~44 W.
>
> **So there is no software rate limiter.** If you want a gentler charge *rate*,
> use a **lower-wattage PD charger** — a 30 W or 45 W brick caps the total, and
> the battery takes what is left after system draw. That is a hardware lever, not
> a software one.
>
> Observed directly: when the PD contract renegotiated from **3 A** down to
> **1.5 A** (`current_now=1500000`, ~30 W), the charge rate fell from ~44 W to
> **~20 W** with the charge mode untouched. The contract sets the rate.
>
> The real longevity lever in software is `Long_Life`: not slower charging, but
> never parking the cell at 100%. High state-of-charge is what drives calendar
> aging.
>
> <sub>Caveat: those figures were all sampled at 25–28% SoC. `Fast` and
> `Standard` may still diverge higher up the curve, where Rapid Charge could hold
> constant-current longer or terminate at a higher voltage — untested.</sub>

```bash
sudo ./scripts/setup-battery-care.sh              # install + select Standard
sudo ./scripts/setup-battery-care.sh conservation # install + select Long_Life
battery-care status                               # mode, live rate, health, cycles
battery-care watch                                # live charge rate, 1 Hz
battery-care fast | standard | conservation       # switch, no sudo after setup
```

The setup installs a **notification-area indicator** ([`scripts/battery-care-indicator.py`](scripts/battery-care-indicator.py))
showing the current mode and the live charge rate, with a menu to switch between
the three — plus a udev rule that grants your group write access to the knob (so
switching needs no root and no password prompt) and **re-applies your choice at
boot and after an AC plug/unplug**, which the EC otherwise forgets.

> **Don't also use TLP for this.** `Long_Life` *is* conservation mode — the
> kernel driver says so outright: *"conservation_mode attribute has been
> deprecated, see charge_types"*. TLP's lenovo plugin still writes that old
> `conservation_mode` file, so if you set `STOP_CHARGE_THRESH_BAT0` in
> `tlp.conf` the two will fight on every AC transition. The setup script warns
> you if it finds such a setting. Note also that TLP's lenovo plugin treats that
> value as a **boolean** (0/1), not a percentage.

---

## Get your own hardware fingerprint (`~/aboutme.md`)

Cloned this repo but **don't** have this exact laptop? Generate the same kind of
component-by-component reference for *your* machine — every device with its
PCI/USB ID and the kernel module that drives it, plus CPU/RAM/disk/display/
battery/firmware:

```bash
./scripts/hardware-fingerprint.sh            # writes ~/aboutme.md (your private copy)
sudo ./scripts/hardware-fingerprint.sh       # also includes serials & DMI UUID
./scripts/hardware-fingerprint.sh -r         # redacted copy, safe to attach to an issue/PR
./scripts/hardware-fingerprint.sh --stdout   # print instead of writing a file
```

It **only reads** (`lspci`, `lsusb`, `lscpu`, `dmidecode`, `xrandr`, `upower`, …) —
nothing on your system is changed; the sole output is the Markdown file. This is
the automated version of the [regenerate one-liners](docs/hardware-reference.md#3-handy-one-liners-to-regenerate-this-info-later)
in the reference doc.

> **Privacy:** the default `~/aboutme.md` is *your* copy and includes real
> serials/UUIDs/MACs. Per this repo's contributing rule, run with **`-r`** before
> pasting it anywhere public — that scrubs serials, the DMI UUID, machine-id and
> MAC addresses to `REDACTED…` / `xx:xx` placeholders, just like the reference doc.

---

## Help others find this laptop (optional)

The [Linux Hardware Database](https://linux-hardware.org) collects anonymized
hardware probes, and its per-model pages rank well in search — so a probe for this
machine helps the *next* person discover that the Yoga Slim 7 14AGP11 (83QS) runs
Linux, and points them here. Contributing one is a small kindness to the community:

```bash
./scripts/upload-hw-probe.sh     # interactive & opt-in: install? review? upload?
```

It uses the standard **`hw-probe`** tool (offers to install it if missing),
lets you **inspect the probe locally first**, and only uploads on an explicit
*yes*. Per hw-probe's design, **no** hostname, IPs, MACs, UUIDs or serials are
sent — only device/driver info and salted hash prefixes, over HTTPS. You get a
public probe URL back; drop it in an issue or here so others can cross-check.

---

## Repository layout

```
docs/
  hardware-reference.md   Full spec: every device, its PCI/USB ID and kernel module
  freeze-diagnosis.md     The amdgpu freeze investigation, evidence, escalation path
scripts/
  fix-amdgpu-freeze.sh    Applies the PSR/Panel-Replay fix (+ 60 Hz cap, idempotent)
  brightness-step.sh      Perceptual backlight stepper (logind, no root)
  setup-brightness-keys.sh  Installs the stepper and rebinds the brightness keys
  setup-screenshots.sh    Region-screenshot key bindings + clipboard manager
  setup-tty-font.sh       Large console font for the 2.8K panel (+ initramfs, readable early boot)
  setup-battery-care.sh   Installs charge-mode control: CLI + udev rule + panel indicator
  battery-care.sh         Read/set the EC charge mode (Fast / Standard / Long_Life, ~60% cap)
  battery-care-indicator.py  Notification-area indicator: current mode, live charge rate, switcher
  hardware-fingerprint.sh Generate ~/aboutme.md — your machine's own hardware/driver reference
  upload-hw-probe.sh      Opt-in: share an anonymized probe to linux-hardware.org (helps discoverability)
```

## Contributing

Got the same laptop (or the 14ILL10 sibling)? Reports of what worked/didn't on your
kernel, distro, or BIOS are welcome — open an issue or PR. Please **don't paste raw
serials, UUIDs, machine-id, or MAC addresses** into issues; redact them like the
reference doc does.

## Disclaimer

Provided as-is (MIT). These steps edit GRUB, kernel parameters, and desktop config
on **very new hardware** — read what a script does before running it, and keep a
backup. What worked here may differ on your firmware/kernel.

## License

[MIT](LICENSE). Scripts and documentation alike — reuse freely.
