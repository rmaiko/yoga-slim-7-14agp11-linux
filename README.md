# Lenovo Yoga Slim 7 14AGP11 (83QS) on Linux

Setup notes, fixes, and a full hardware/driver reference for running **Linux
(Ubuntu 26.04 / XFCE)** on the **Lenovo Yoga Slim 7 14AGP11** — machine type
**83QS**, the **AMD** variant with the **Ryzen AI 7 445 / Radeon 840M** (Krackan
Point, RDNA 3.5, ISA `gfx1153`) and a **2.8K 120 Hz OLED** panel.

> ⚠️ **Not the 14ILL10.** `14AGP11` (`AGP` = AMD) is a *different machine* from the
> Intel Lunar Lake `Yoga Slim 7 14ILL10`. If you have the AMD one, you're in the
> right place. Search terms that land here: **Yoga Slim 7 14AGP11**, **83QS**,
> **Radeon 840M**, **Krackan Point**, **amdgpu freeze**.

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
  hardware-fingerprint.sh Generate ~/aboutme.md — your machine's own hardware/driver reference
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
