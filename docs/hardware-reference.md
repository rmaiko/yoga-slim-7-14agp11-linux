# Hardware & Driver Reference — Lenovo Yoga Slim 7 14AGP11 (83QS)

> A single-file, self-contained hardware & driver reference for this laptop.
> Originally written as a personal note-to-self on 2026-07-22 so that **years from
> now** you can open one file and resolve any driver problem (e.g. "my webcam won't
> load") without re-discovering the hardware. Every component below lists its
> **PCI/USB ID** and the **kernel module (driver)** that binds it — that pairing is
> what you need to debug drivers.
>
> **Privacy note:** per-unit identifiers from the machine this was captured on
> (system/SSD/battery serials, DMI UUID, machine-id, Wi-Fi/Bluetooth MAC addresses)
> have been replaced with `REDACTED…` / `xx:xx:…` placeholders. Everything else —
> PCI/USB IDs, subsystem IDs, kernel modules, kernel parameters — is identical
> across every unit of this model and is what makes the doc useful. Regenerate your
> own values with the one-liners in §3.

---

## ⚠️ Important identity correction — read this first

It is easy to mistake this machine for a **"Lenovo Yoga Slim 7 14ILL10"**. That is
**not** what the firmware reports. The board's own DMI/firmware says:

- **Marketing name:** Lenovo **Yoga Slim 7 14AGP11**
- **Machine Type (MT):** **83QS**
- **SKU string:** `LENOVO_MT_83QS_BU_idea_FM_Yoga Slim 7 14AGP11`

The `AGP` in `14AGP11` denotes the **AMD** variant (Ryzen AI). `14ILL10` would be an
**Intel** Lunar Lake sibling — a different machine. **This laptop is the AMD one.**
When ordering parts, searching forums, or downloading firmware/drivers, search for
**"Yoga Slim 7 14AGP11"** or **"83QS"**, not 14ILL10.

---

## 1. Full specifications

### 1.1 Identity / chassis
| Field | Value |
|---|---|
| Vendor | LENOVO |
| Marketing model | Yoga Slim 7 14AGP11 |
| Machine Type (MT) | 83QS |
| Product name (DMI) | 83QS |
| Board / motherboard | LNVNB161216 (board version `SDK0T76574 WIN`) |
| Chassis | Laptop, convertible-class |
| Hostname | `fridolin` |
| Machine ID | `REDACTED-MACHINE-ID` |
| DMI subsystem vendor ID | `17aa` (Lenovo) — appears on most onboard devices |

> **Serial numbers (captured via `sudo dmidecode`, 2026-07-22):**
> | Item | Serial |
> |---|---|
> | **System serial** (the one on the sticker / for Lenovo warranty & parts) | **`REDACTED-SERIAL`** |
> | Base board serial | `REDACTED-SERIAL` (same value) |
> | Chassis serial | `REDACTED-SERIAL` (same value) |
> | System **UUID** | `REDACTED-UUID` |
> | SSD serial | `REDACTED-SSD-SERIAL` |
> | Battery serial | `REDACTED` |
>
> Chassis type: **Notebook**. Asset Tag: none set (`NO Asset Tag`).
> Use **`REDACTED-SERIAL`** on Lenovo's support site / when ordering parts under warranty.

### 1.2 BIOS / firmware
| Field | Value |
|---|---|
| BIOS vendor | LENOVO |
| BIOS version | **TFCN21WW** |
| BIOS date | 2025-12-19 |
| CPU microcode | `0xb608038` |
| Secure Boot / EFI | UEFI, ESP at `/boot/efi` (nvme0n1p1, 450 MB) |

### 1.3 Operating system (as of writing)
| Field | Value |
|---|---|
| OS | Ubuntu **26.04 LTS** (Resolute Raccoon) |
| Kernel | **7.0.0-14-generic** (x86-64) |
| Desktop | XFCE (xfwm4), display manager LightDM, session **X11 / Xorg** |
| Mesa (graphics userspace) | **26.0.3-1ubuntu1** |

### 1.4 CPU
| Field | Value |
|---|---|
| Model | **AMD Ryzen AI 7 445 w/ Radeon 840M** |
| Family / Model / Stepping | 26 (0x1A "Zen 5") / 104 / 0 |
| Cores / threads | **6 cores / 12 threads** |
| Max boost | ~4.67 GHz (min ~0.62 GHz) |
| Cache | L1d 288 KiB, L1i 192 KiB, L2 6 MiB, L3 8 MiB |
| Virtualization | AMD-V (SVM) |
| Codename | Krackan Point (Ryzen AI 300 class) |

### 1.5 GPU (integrated)
| Field | Value |
|---|---|
| Marketing name | **AMD Radeon 840M** |
| Silicon | **Krackan2** APU, RDNA 3.5, ISA **gfx1153** |
| PCI address | `c1:00.0` |
| PCI ID | **`1002:1902`** (rev c0), subsystem `17aa:380c` |
| Kernel driver | **`amdgpu`** |
| Userspace | Mesa radeonsi / ACO, DRM 3.64 |
| Notes | This is the display controller behind the freeze bug — see §2. |

### 1.6 NPU (AI accelerator)
| Field | Value |
|---|---|
| Device | AMD **XDNA** Neural Processing Unit (Strix/Krackan class) |
| PCI address | `c2:00.1` |
| PCI ID | **`1022:17f0`** (rev 20), subsystem `17aa:3845` |
| Kernel driver | **`amdxdna`** (exposes `/dev/accel/accel0`) |

### 1.7 Memory (RAM)
| Field | Value |
|---|---|
| Total | **32 GB** (`MemTotal` 32,155,412 kB) |
| Type | LPDDR5x, **soldered on-package/board — not user-replaceable** (typical for this chassis) |
| Per-module detail | Requires `sudo dmidecode -t memory` (not captured; likely reports as onboard/soldered) |
| Swap | 37 GiB (partition `nvme0n1p5`) |

### 1.8 Storage
| Field | Value |
|---|---|
| Model | **Micron MTFDKCD1T0QHK-1BQ1AABLA** (Micron 2600, DRAM-less NVMe) |
| Capacity | ~1 TB (1,024,209,543,168 bytes) |
| Serial | **`REDACTED-SSD-SERIAL`** |
| Firmware | `1001V9LN` |
| Node | `/dev/nvme0n1` |
| PCI address | `bf:00.0`, PCI ID **`1344:5429`** (rev 01) |
| Driver | **`nvme`** |
| Partitions | p1 ESP 450M `/boot/efi` · p2 16M · p3 93G `/` · p4 2G · p5 37G swap · p6 821G `/home` |

### 1.9 Display / internal panel
| Field | Value |
|---|---|
| Connector | **eDP-1** (internal) |
| Panel model (EDID) | **`LEN140WQ+`** (Lenovo `LEN`, product code 0x8ad6) |
| Technology | **OLED** (confirmed by `panel_type: OLED` in DRM) |
| Native resolution | **2880 × 1800** |
| Refresh rates | 60 Hz and 120 Hz (currently forced to **60 Hz** — see §2) |
| Physical size | 300 mm × 190 mm (~14") |
| Features | VRR-capable, HDCP (Type0/Type1), backlight via `amdgpu_bl1` |
| External outputs | HDMI-A-1 + up to 7 DP (over USB-C/USB4), all currently disconnected |

### 1.10 Wi-Fi
| Field | Value |
|---|---|
| Adapter | **MediaTek MT7925** (Filogic 360), Wi-Fi 7 / 802.11be, 160 MHz 2×2 |
| PCI address | `c0:00.0`, PCI ID **`14c3:7925`**, subsystem `17aa:e0ff` |
| Kernel driver | **`mt7925e`** |
| Interface | `wlp192s0`, MAC `xx:xx:xx:xx:xx:xx` |
| rfkill name | `ideapad_wlan` / `phy0` |

### 1.11 Bluetooth
| Field | Value |
|---|---|
| Radio | **MediaTek** (same MT7925 combo module), BT 5.4 |
| Bus | USB, ID **`0489:e111`** (Foxconn/Hon Hai enclosure) → controller `hci0` |
| Driver | **`btusb`** |
| BD address | `xx:xx:xx:xx:xx:xx` |
| rfkill name | `ideapad_bluetooth` / `hci0` |

### 1.12 Audio
| Component | Value |
|---|---|
| Codec (speakers/headset) | **Realtek ALC287** (`0x10ec0287`, subsystem `17aa:394c`), driver `snd_hda_intel` — note: DMI/firmware onboard-device table mislabels it "Realtek ALC245"; the live-detected codec **ALC287** is authoritative |
| HDMI/DP audio | AMD/ATI "ATI R6xx HDMI" (`1002:1640`) on `c1:00.1`, driver `snd_hda_intel` |
| Digital-mic / DSP | AMD **ACP7.0** Audio Coprocessor (`1022:15e2` at `c1:00.5`), SOF driver `snd_sof_amd_acp70`; machine `acp-pdm-mach` = `LENOVO-83QS-YogaSlim714AGP11` |
| Extra HD Audio ctrl | AMD Ryzen HD Audio (`1022:15e3` at `c1:00.6`) |

### 1.13 Webcam (RGB **+ IR**)
| Field | Value |
|---|---|
| Module | **Syntek / SunplusIT Integrated RGB Camera** |
| USB ID | **`174f:11bf`** (USB 2.0) |
| Driver | **`uvcvideo`** (standard USB Video Class — appears as `/dev/video*`) |
| UVC functions | **Two**: interfaces 0/1 = RGB, interfaces 2/3 = **IR**. (Interface 4 is a vendor "Application Specific" interface with no driver — normal.) Both report the same product string, so all four `/dev/video*` nodes are named "Integrated RGB Camera" — the name is misleading, tell them apart by pixel format. |
| `/dev/video0` | **RGB** — MJPG + YUYV. (`/dev/video1` is its metadata node.) |
| `/dev/video2` | **IR** — `GREY` 8-bit greyscale, 640×360. (`/dev/video3` is its metadata node.) |
| Notes | An IR / Windows-Hello-class sensor **is** present and **is** exposed on Linux — verified 2026-07-23 by capturing live frames from `/dev/video2` (mean 38, peak 254 with the emitter on). **Gotcha:** the IR emitter takes ~15 frames to fire, so the first frames come back all-zero — a single-frame test looks like a dead device. Grab 30–40 frames before concluding anything. This enables face unlock via Howdy — see §4. If the cam "won't load", this is the device to check: `lsusb -d 174f:11bf` and `dmesg \| grep uvc`. |

### 1.14 Input devices
| Device | Detail |
|---|---|
| Touchpad | **Synaptics `SYNA2BA6:00 06CB:CFD8`** (I²C HID; presents Touchpad + Mouse) |
| Keyboard | AT Translated Set 2 keyboard (internal) |
| Hotkeys / lid / rotation | `Ideapad extra buttons`, `Lid Switch`, `Video Bus`, `gpio-keys` — via **`ideapad_laptop`** platform driver (ACPI `VPC2004`) |
| Fingerprint reader | **None — this unit has no fingerprint sensor at all.** Verified 2026-07-23 across every bus it could hide on; see §4. Don't waste time hunting for a driver. |

> **Decoy ACPI entries — don't be fooled.** The firmware declares alternate
> touchpad/touchscreen stubs for other component suppliers: `ELAN06FA`
> (`\_SB_.I2CA.TPDF`), `GXTP7936` (`\_SB_.I2CB.TPN1`), `CIRQ1080`
> (`\_SB_.I2CA.TPDE`), `LTCN0001` (`\_SB_.I2CB.TCON`). All read `status = 0`
> (**not present**) — they are *not* fingerprint or extra input hardware, just
> unused build-option branches. The live touchpad is the Synaptics one above.
> Check any ACPI device with: `cat /sys/bus/acpi/devices/<ID>:00/{status,path}`

### 1.15 Battery
| Field | Value |
|---|---|
| Manufacturer | **ATL** |
| Model | **L25N4PH1** |
| Serial | **`REDACTED`** |
| Chemistry | Li-ion (4-cell, 15.48 V nominal) |
| Design capacity | **70 Wh** |
| Cycle count (at writing) | 2 (essentially new) |
| USB-C PD | 3× UCSI USB-C power ports (`USBC000:001..003`) |

### 1.16 USB / USB4 / Thunderbolt
- Multiple AMD xHCI controllers at `c1:00.4`, `c3:00.0/0.3/0.4` (driver `xhci_hcd`).
- **USB4 / Thunderbolt** controllers at `c3:00.5` and `c3:00.6` (driver `thunderbolt`);
  domains `domain0`/`domain1` — these drive the USB-C ports' DisplayPort-alt + USB4.
- Security co-processor **AMD CCP** (`1022:1134` at `c1:00.2`, driver `ccp`).

### 1.17 Driver → component quick map (the "why won't X load" table)
| Symptom / component | PCI or USB ID | Kernel module | First debug step |
|---|---|---|---|
| **Display / freeze / brightness** | `1002:1902` | `amdgpu` | `dmesg \| grep -iE 'amdgpu\|dmub\|dcn'` ; see §2 |
| **Webcam not loading** | `174f:11bf` | `uvcvideo` | `lsusb -d 174f:11bf` ; `modprobe uvcvideo` ; `dmesg \| grep uvc` |
| **Wi-Fi down** | `14c3:7925` | `mt7925e` | `rfkill list` ; `dmesg \| grep mt7925` ; check `linux-firmware` for `mediatek/mt7925*` |
| **Bluetooth down** | `0489:e111` | `btusb` | `rfkill list` ; `dmesg \| grep -i bluetooth` ; firmware `mediatek/BT_RAM_CODE_*` |
| **No sound** | `10ec:0287` | `snd_hda_intel` (+ `snd_sof_amd_acp70`) | `aplay -l` ; `dmesg \| grep -iE 'snd\|sof\|acp'` |
| **NVMe/disk** | `1344:5429` | `nvme` | `nvme list` (as root) ; `dmesg \| grep nvme` |
| **NPU / AI accel** | `1022:17f0` | `amdxdna` | `ls /dev/accel/` ; `dmesg \| grep amdxdna` |
| **Touchpad** | `06CB:CFD8` | `hid_multitouch` / i2c-hid | `libinput list-devices` ; `dmesg \| grep -i syna` |
| **Hotkeys/lid/rotate** | ACPI `VPC2004` | `ideapad_laptop` | `dmesg \| grep ideapad` |
| **USB-C dock / ext display** | `1022:113b/c` | `thunderbolt`, `amdgpu` | `boltctl list` ; check TearFree / DP-alt |

> **Golden rule for driver problems on this box:** most silicon is very new AMD
> (Krackan / Zen 5 / RDNA 3.5, 2025-era). When something misbehaves, the fix is
> almost always **newer kernel + newer `linux-firmware`**, because the driver code
> and GPU/Wi-Fi microcode were still maturing when this machine shipped:
> ```
> sudo apt update && sudo apt full-upgrade
> sudo apt install --reinstall linux-firmware
> ```

---

## 2. Current fixes applied to this machine

All fixes below target a single problem: an **`amdgpu` display freeze** (screen
stuck on a stale frame while the **mouse cursor still moves**; TTYs and the rest of
the system stay alive). Full investigation and evidence are in
**`docs/freeze-diagnosis.md`**; the applier script is **`scripts/fix-amdgpu-freeze.sh`**.
Root cause (primary hypothesis): a stuck panel **self-refresh** feature (PSR / Panel
Replay) on new AMD silicon wedging the display pipe.

### Fix 1 — Disable PSR + Panel Replay via kernel parameter *(ACTIVE, verified)*
- **Parameter:** `amdgpu.dcdebugmask=0x410` (`0x10` = disable PSR, `0x400` = disable Panel Replay).
- **Applied in:** `/etc/default/grub` → `GRUB_CMDLINE_LINUX_DEFAULT="amdgpu.dcdebugmask=0x410"`, then `update-grub`.
- **Verified live at time of writing:**
  - `/proc/cmdline` contains `amdgpu.dcdebugmask=0x410` ✅
  - `/sys/module/amdgpu/parameters/dcdebugmask` reads **`1040`** (= 0x410) ✅
- **Impact:** turns off a power-saving feature only; worst case is slightly worse idle battery. No stability downside. Fully reversible.
- **Backup created:** `/etc/default/grub.bak.20260722-131458`
- **Revert:** `sudo cp /etc/default/grub.bak.* /etc/default/grub && sudo update-grub && sudo reboot`

### Fix 2 — Cap the OLED panel at 60 Hz *(ACTIVE)*
Lowers the pixel clock / display-engine load (an independent lever on the same freeze class). The panel supports 60 and 120 Hz; it is currently running at **60 Hz** (verified: `xrandr` shows `60.00*` on eDP). Because XFCE restores its saved display config at login, this is enforced by a login autostart, not a one-shot:
- `~/.local/bin/force-60hz.sh` — runs `xrandr --output eDP --mode 2880x1800 --rate 60` with retries.
- `~/.config/autostart/force-60hz.desktop` — launches it 2 s after each login.
- **Revert:** `rm ~/.config/autostart/force-60hz.desktop ~/.local/bin/force-60hz.sh`, then set 120 Hz in XFCE Display settings (or `xrandr --output eDP --rate 120`).

### Fix 3 — Bluetooth re-enabled *(ACTIVE)*
Bluetooth had been disabled earlier under the mistaken belief it caused the freeze (the journal lines were just normal shutdown teardown). It was ruled out and **re-enabled**: `bluetooth.service` is now **enabled + active** (verified).

### If the freeze still happens — escalation (summary; full detail in `diagnosis.md`)
1. Widen the mask: `amdgpu.dcdebugmask=0x412` (adds `0x2` = disable stutter).
2. Update kernel + `linux-firmware`, reboot (best long-term fix on new silicon).
3. **Capture a live freeze from a TTY before rebooting** — the single most useful missing data point:
   `sudo dmesg | tail -100 > ~/freeze-$(date +%H%M).log`
4. Try `amdgpu.aspm=0` (PCIe power-management hang, a mimic).
5. Test a newer/mainline kernel.
6. Disable XFCE compositing to rule out the xfwm4↔amdgpu present path.

**Recovery when it freezes (cheapest first):**
1. `Ctrl+Alt+F3` then `Ctrl+Alt+F2` — VT switch forces a modeset that may un-wedge the pipe **without losing your session**.
2. From a TTY: `sudo systemctl restart lightdm` — **confirmed to recover** the UI, but closes all apps.

---

## 3. Handy one-liners to regenerate this info later
```bash
# Identity / firmware / serials (serials need root)
sudo dmidecode -t system -t baseboard -t chassis
inxi -Fxxxz            # if installed, a great single-shot overview

# Per-device driver bindings
lspci -nnk             # every PCI device + its kernel driver + PCI ID
lsusb                  # USB devices (webcam, BT)

# Component specifics
cat /sys/class/dmi/id/{product_version,product_serial,board_serial}   # (serial needs root)
sudo dmidecode -t memory                       # RAM modules
sudo nvme list ; nvme id-ctrl /dev/nvme0       # SSD
DISPLAY=:0 xrandr --verbose                    # panel/EDID/refresh
upower -i $(upower -e | grep BAT)              # battery health

# Freeze-fix state check
cat /proc/cmdline
cat /sys/module/amdgpu/parameters/dcdebugmask  # expect 1040

# Biometric hardware audit (see §4)
lsusb -t                                  # FP readers are almost always USB
ls /sys/bus/spi/devices/                  # SPI/MOC readers (empty on this box)
ls /sys/bus/acpi/devices/ | grep -iE 'GXFP|FPC|EGIS|VFS|AUTH|FPS'
grep -E '^N:' /proc/bus/input/devices
```

---

## 4. Biometric login (fingerprint / face)

**Bottom line: no fingerprint reader — but the IR camera works, so face unlock is viable.**

### 4.1 Fingerprint — hardware is absent, not undriven
Audited 2026-07-23. This is a *hardware* absence; no kernel/firmware update will
ever produce a fingerprint device on this board.

| Bus checked | How | Result |
|---|---|---|
| USB | `lsusb -t` | Only camera `174f:11bf`, BT `0489:e111`. No Goodix / Synaptics / Elan / Validity / Egis FP device |
| SPI | `ls /sys/bus/spi/devices/` | **Empty** — rules out SPI "match-on-chip" readers |
| ACPI | `ls /sys/bus/acpi/devices/` | No `GXFP`/`FPC`/`FPS`/`AUTH` device. Elan/Goodix entries present are `status = 0` touchpad stubs — see §1.14 |
| Input layer | `/proc/bus/input/devices` | Lid, keyboard, gpio-keys, Video Bus, Synaptics touchpad, Ideapad buttons. Nothing else |

`fprintd` + `libpam-fprintd` are in the Ubuntu 26.04 repos and will install
cleanly — **and then find zero devices.** Installing them proves nothing.

**If you want fingerprint specifically:** external USB reader on the
[libfprint supported-devices list](https://fprint.freedesktop.org/supported-devices.html),
driven by the stock `fprintd` / `libpam-fprintd`. Check the list *before* buying —
most cheap dongles are unsupported.

### 4.2 Face unlock via Howdy — the option that fits this hardware
Uses the IR camera at **`/dev/video2`** (§1.13). Howdy is a PAM module, so it
covers LightDM login, `sudo`, and polkit prompts.

- **Not in the Ubuntu repos** (checked 2026-07-23 — `apt-cache policy howdy` returns
  no candidate). Install from the upstream `.deb` / PPA.
- Point its config at **`/dev/video2`**, not `/dev/video0` — `video0` is the RGB
  sensor and will fail in the dark, which is the whole point of using IR.
- **Security caveat:** Howdy is 2D IR matching with **no depth check**, so it is
  meaningfully weaker than Windows Hello's structured light and can be defeated by
  a good IR-visible photo. Treat it as convenience, not as a security boundary.
- **⚠️ Lockout trap:** add it as **`sufficient`** *above* `@include common-auth`,
  **never `required`**. As `required`, any camera failure (device busy, kernel
  regression, lid closed) locks you out of `sudo` *and* the login screen. Always
  keep a root TTY open while editing files in `/etc/pam.d/`, and test in that
  spare TTY before logging out.

*Last verified: 2026-07-22 on kernel 7.0.0-14-generic, Ubuntu 26.04.*
*§1.13, §1.14 and §4 (camera IR function + biometrics audit) verified 2026-07-23.*

---

## 5. Display brightness — perceptual (fine-grained) control *(ACTIVE, added 2026-07-24)*

**Problem:** XFCE Power Manager 4.20 stepped the OLED backlight **linearly by
percentage** and **refused to go below a minimum** (never reached 0). Because the
panel's raw range is huge (`0..495000`, device `amdgpu_bl1`) and human brightness
perception is roughly logarithmic, each linear % step felt **enormous when already
dim** — the exact complaint.

**Fix:** took the brightness keys away from Power Manager and gave them to a small
script that walks a precomputed **exponential ladder** (30 steps): sub-1% steps at
the bottom (609, 719, 850, 1004… raw), coarser steps at the top, and a real **0**
(panel fully dark). Writes go through **systemd-logind `SetBrightness`** for the
active session, so **no root/sudo, no udev rule, no group change** was needed.

- **Script:** `~/.local/bin/brightness-step.sh` — `up | down | get | set <pct> | ladder`.
  Reads `max_brightness` at runtime; writes via
  `gdbus … org.freedesktop.login1.Session.SetBrightness backlight amdgpu_bl1 <raw>`.
  Shows an OSD bar via `notify-send` (replaces the popup Power Manager used to draw).
  Tunables at the top: `N=30` (number of steps), `K=5` (curve steepness — higher =
  finer at the low end / coarser at top). Re-run `brightness-step.sh ladder` after
  changing them to see the resulting stops.
- **Power Manager disabled from the keys:**
  `xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/handle-brightness-keys -s false`
  (the panel-plugin brightness slider still works; only the key grab was dropped).
- **Key bindings (xfsettingsd, live — no logout needed):**
  `/commands/custom/XF86MonBrightnessUp`  → `…/brightness-step.sh up`
  `/commands/custom/XF86MonBrightnessDown` → `…/brightness-step.sh down`
- **Note:** brightness `0` makes the screen fully black; press **brightness-up**
  (works blind) to bring it back. This is intended per request.

**Revert to stock Power Manager behaviour:**
```bash
xfconf-query -c xfce4-keyboard-shortcuts -r -p /commands/custom/XF86MonBrightnessUp
xfconf-query -c xfce4-keyboard-shortcuts -r -p /commands/custom/XF86MonBrightnessDown
xfconf-query -c xfce4-power-manager -p /xfce4-power-manager/handle-brightness-keys -s true
xfce4-power-manager --quit && xfce4-power-manager   # or just re-login
rm ~/.local/bin/brightness-step.sh
```

*§5 (brightness) added & verified 2026-07-24 on kernel 7.0.0-14-generic.*

---

## 6. Screenshots — macOS-style region capture *(ACTIVE, added 2026-07-24)*

Reworked the `Print` key from "fullscreen + action dialog" to a macOS-like
**click-drag region selection**, using the already-installed **`xfce4-screenshooter`
1.11.1** (no new tools). Region select = press key, drag a rectangle, release.

**Key map** (xfconf channel `xfce4-keyboard-shortcuts`, `/commands/custom/…`):

| Shortcut | Command | Behaviour |
|---|---|---|
| **`Print`** | `xfce4-screenshooter -r -s ~/Pictures/Screenshots` | region → **saved PNG** (silent, auto-named `Screenshot_YYYY-MM-DD_HH-MM-SS.png`) |
| **`Ctrl+Print`** | `xfce4-screenshooter -r -c` | region → **clipboard** |
| `Ctrl+Shift+Print` | `xfce4-screenshooter -f -s ~/Pictures/Screenshots` | fullscreen → saved PNG (kept because plain Print no longer does fullscreen) |
| `Shift+Print` | `xfce4-screenshooter -r` | region → post-capture action dialog (stock; left as fallback) |
| `Alt+Print` | `xfce4-screenshooter -w` | active window (stock) |

Save directory: **`~/Pictures/Screenshots/`** (created). `-s <dir>` auto-names and
saves with **no dialog**.

### ⚠️ The clipboard gotcha — why `xfce4-clipman` must be running
On X11, an image copied to the clipboard is **lost the instant the copying program
exits** unless a *clipboard manager* takes ownership of it. `xfce4-screenshooter -c`
exits immediately, so **without a manager, `Ctrl+Print` produces an empty
clipboard** (verified 2026-07-24: with no manager the image survived only
inconsistently for a second or two; with `xfce4-clipman` running it persisted
reliably across every trial).

- Fix: ensure **`xfce4-clipman`** (already installed) runs. Its autostart file
  `~/.config/autostart/xfce4-clipman-plugin-autostart.desktop` is enabled
  (`Hidden=false`, `OnlyShowIn=XFCE`), so it starts on every XFCE login. It was
  started manually for the session in which this was set up.
- **If `Ctrl+Print` ever pastes nothing:** check `pgrep -x xfce4-clipman`; if empty,
  run `setsid xfce4-clipman &` (and confirm the autostart file above still exists).
  The file-saving `Print` key does **not** depend on clipman.

Bindings apply live (xfsettingsd watches the channel) — no logout needed.

**Revert to stock:**
```bash
for k in Print '<Primary>Print' '<Primary><Shift>Print'; do
  xfconf-query -c xfce4-keyboard-shortcuts -r -p "/commands/custom/$k"
done
# restore old defaults if wanted:
xfconf-query -c xfce4-keyboard-shortcuts -p /commands/custom/Print -n -t string -s 'xfce4-screenshooter -f'
```

*§6 (screenshots) added & verified 2026-07-24 on kernel 7.0.0-14-generic.*

---

## 7. Readable text consoles on the 2.8K panel *(ACTIVE, added 2026-07-24)*

**Problem:** the internal panel is **2880 × 1800** (§1.9). The virtual consoles
(`Ctrl+Alt+F3`…`F6`) and the early-boot kernel/initramfs messages render with the
default **~8×16** console font, which at this pixel density is **microscopic** —
roughly 360 columns of unreadable text. This bites exactly when you need a TTY:
recovery, or capturing a live freeze (§2).

**Fix:** a large **DejaVu** console font, set in `/etc/default/console-setup` and
applied with `setupcon`. The non-obvious half: also **`update-initramfs -u`**, so
the font is present in the initramfs and applies from *early* boot — otherwise the
boot messages stay tiny until the desktop's `console-setup` service runs late.

- **Config (`/etc/default/console-setup`):**
  ```
  FONTFACE="DejaVu"
  FONTSIZE="24x43"      # WIDTHxHEIGHT; ≈ 120 cols × 41 rows at 2880×1800
  ```
  Note the ordering quirk: `FONTSIZE` is **WIDTHxHEIGHT**, but the font *files*
  are named `…-DejaVu<HEIGHT>x<WIDTH>.psf.gz` (so `24x43` ↔ `DejaVu43x24`).
  Available DejaVu sizes: `16x30, 20x36, 24x43, 28x51, 32x59, 40x74, 48x89,
  64x118` — go bigger (e.g. `32x59`) if 24x43 still feels small.
- **Applier script:** `scripts/setup-tty-font.sh` (validates the size against
  installed fonts, backs up the config, runs `setupcon` **and**
  `update-initramfs -u`). `--list` shows sizes, `--show` prints the current config.
- **Apply by hand:**
  ```bash
  sudo sed -i 's/^FONTFACE=.*/FONTFACE="DejaVu"/;  s/^FONTSIZE=.*/FONTSIZE="24x43"/' /etc/default/console-setup
  sudo setupcon --force
  sudo update-initramfs -u
  ```
- **Verify:** switch to a console with `Ctrl+Alt+F3` (text should be large);
  `setfont --help` / `showconsolefont` show the loaded glyphs. Return to the
  desktop with `Ctrl+Alt+F2` (or F1).
- **Revert:** restore the `console-setup.bak.*` backup, then re-run `setupcon` and
  `update-initramfs -u`.

> Why **DejaVu** and not Terminus: Terminus caps at 16×32 px here, whereas DejaVu
> scales up to 64×118 — the headroom you want on a 2.8K panel.

*§7 (console font) added 2026-07-24 on kernel 7.0.0-14-generic.*
