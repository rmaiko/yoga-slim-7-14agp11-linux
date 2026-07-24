# Display Freeze Diagnosis & Handoff

**Machine:** Lenovo Yoga 7 (AMD), hostname `fridolin`
**OS:** Ubuntu 26.04 LTS (Resolute Raccoon), XFCE desktop (xfwm4), LightDM, X11 (Xorg)
**Kernel:** 7.0.0-14-generic
**GPU:** AMD Krackan2 APU `[1002:1902]` (RDNA 3.5 / Ryzen AI 300 class), driver `amdgpu`
**Date of investigation:** 2026-07-22
**Investigator:** Claude (Opus 4.8), working from a TTY while X was frozen

---

## Symptom

The X session (on the graphical VT) freezes: the **screen is stuck on a stale frame**, but the **mouse cursor still moves**. The rest of the system is unaffected — TTYs are responsive, journald keeps logging, and the machine can be cleanly shut down from a text console.

- First observed ~22:23 on 2026-07-21.
- Reproduced again on 2026-07-22 (during this session).
- Triggers reported by user: **once while a video was trying to play**, but also **during normal work** with no obvious trigger.

---

## Hypothesis (primary)

**An `amdgpu` display-controller (DCN) hang caused by a stuck panel self-refresh feature — PSR (Panel Self Refresh) and/or its newer variant Panel Replay.**

On these features the panel redraws itself from its own internal buffer to save power. On brand-new hardware + early driver stacks, the self-refresh pipe can wedge and hold a stale frame. The **hardware cursor plane** is driven independently of the main display pipe, which is why the cursor keeps moving while everything else is frozen. Video playback forces a display-clock (MCLK/DCFCLK) switch, a well-known moment for such a pipe to hang — consistent with the video-triggered instance.

This is a common, well-documented failure class on 2024–2025 AMD laptop panels.

---

## Evidence backing the hypothesis

| Observation | How it was obtained | Why it supports the hypothesis |
|---|---|---|
| Cursor moves, screen frozen | User report | Hardware cursor plane updates independently of the wedged display pipe |
| Xorg = ~2% CPU, xfwm4 = ~1%, both idle (`Ssl+`) | `ps -eo pid,ppid,stat,pcpu,...` | Not a software busy-loop; userspace is healthy — failure is at the display/GPU output layer |
| **Zero** amdgpu / drm / ring-timeout / GPU-reset / fence / hang messages in the current boot's log | `journalctl -b 0 | grep -iE 'amdgpu|drm|gpu reset|ring|timeout|fence|hang|fault'` | A compute-ring GPU hang would log a reset. A silent display-pipe wedge (PSR/Replay) typically does not. |
| No kernel panic, no soft-lockup, journald still logging | `journalctl -b 0 -p warning` | System core healthy; isolated to the display engine |
| `sudo systemctl restart lightdm` recovered a working UI (a fresh Xorg / full modeset), though it closed all apps | User test, 2026-07-22 | The GPU is NOT hard-hung — a modeset un-wedges the display. A modeset resets panel self-refresh state, directly consistent with a PSR/Replay pipe wedge rather than a compute-ring GPU hang. |
| GPU is Krackan2, driver amdgpu, kernel 7.0 | `lspci -nnk | grep -iA3 vga` | Very new silicon with immature driver/firmware support — the population where PSR/Replay bugs cluster |
| Brightness controlled via `backlight:amdgpu_bl1` | shutdown log lines | Internal eDP panel — the kind that uses PSR/Panel Replay |

### Explicitly ruled out: Bluetooth
The user had seen Bluetooth lines in the journal around the first freeze and had disabled Bluetooth, but the freeze recurred. Inspection showed those lines were the **normal shutdown teardown** sequence:

```
bluetoothd: Endpoint unregistered: ... /MediaEndpoint/A2DPSource/...
bluetoothd: Terminating
systemd: Stopped bluetooth.service
```

These appear because the freeze occurred shortly before poweroff, not because Bluetooth caused anything. **Bluetooth is not involved.** The fix script re-enables it.

### Boot timeline (for reference)
`journalctl --list-boots`:
```
-3  2026-07-21 22:02:31 .. 22:11:27
-2  2026-07-21 22:12:32 .. 22:41:30   <- the ~22:23 freeze happened during this boot; ended in a CLEAN poweroff at 22:41 (user shut down from console)
-1  2026-07-21 22:42:33 .. 23:25:54
 0  2026-07-22 12:40:32 .. (current)  <- froze again this session; NO amdgpu errors logged
```
The clean poweroff at 22:41 confirms the kernel/system stayed alive through the freeze — only the display output died.

### Not yet confirmed (debugfs needs root; sudo was not available non-interactively during the session)
The PSR/Replay capability read was **not** captured. To confirm the mechanism directly, run:
```
sudo grep -r . /sys/kernel/debug/dri/*/eDP*/psr_capability /sys/kernel/debug/dri/*/eDP*/psr_state 2>/dev/null
sudo dmesg | grep -iE 'psr|replay|dmub|dcn|amdgpu' | tail -60
```
Capturing `sudo dmesg | tail -80` **at the moment of a fresh freeze (from a TTY, before rebooting)** is the single most valuable missing data point.

### Baseline module params at time of diagnosis (defaults — no override yet)
```
/proc/cmdline: BOOT_IMAGE=/boot/vmlinuz-7.0.0-14-generic root=UUID=... ro   (no amdgpu params)
amdgpu dcdebugmask = 0
amdgpu dc         = -1
amdgpu aspm       = -1
amdgpu ppfeaturemask = 0xfff7bfff
```

---

## Fix applied

Added a kernel parameter that disables PSR and Panel Replay. This only turns off a power-saving feature — worst case is marginally worse idle battery; no stability downside. Fully reversible.

**Parameter:** `amdgpu.dcdebugmask=0x410`
- `0x10`  = disable PSR
- `0x400` = disable Panel Replay
- combined = `0x410` (reads as **1040** in `/sys/module/amdgpu/parameters/dcdebugmask`)

**Applied via** `scripts/fix-amdgpu-freeze.sh`, which:
1. Backs up `/etc/default/grub` to a timestamped `.bak`
2. Sets `GRUB_CMDLINE_LINUX_DEFAULT="amdgpu.dcdebugmask=0x410"`
3. Runs `update-grub`
4. Re-enables Bluetooth
5. Offers to reboot

**Revert:** `sudo cp /etc/default/grub.bak.* /etc/default/grub && sudo update-grub`

### Secondary mitigation also applied: cap panel at 60Hz
The eDP panel (`eDP`, native `2880x1800`) supports both 60Hz and 120Hz. `fix.sh` caps it at **60Hz** to lower the pixel clock / display-engine load — an independent lever on the same freeze class. Because XFCE's settings daemon restores its saved display config at login, this is enforced via a **login autostart** (not a one-shot xrandr):
- `~/.local/bin/force-60hz.sh` — runs `xrandr --output eDP --mode 2880x1800 --rate 60`, with retries so it wins even if it runs before XFCE's daemon.
- `~/.config/autostart/force-60hz.desktop` — launches it at each login (2s delay).

**Revert the 60Hz cap:** `rm ~/.config/autostart/force-60hz.desktop ~/.local/bin/force-60hz.sh` then set the rate back in XFCE Display settings (or `xrandr --output eDP --rate 120`).

Note: a fresh session (e.g. right after `systemctl restart lightdm`) may already report 60Hz in `xrandr`; the user's *saved* XFCE config is what brings it to 120Hz on a normal login, which is why the autostart override is needed.

### Verify the fix is active after reboot
```
cat /proc/cmdline                                  # should contain amdgpu.dcdebugmask=0x410
cat /sys/module/amdgpu/parameters/dcdebugmask      # should read 1040
```

---

## How to judge if the fix worked

Use the machine normally for 1–2 days, and **deliberately re-trigger the known cause** (play the video that froze it before).
- **No freezes** → PSR/Panel Replay confirmed as the cause. Leave the parameter permanently.
- **Still freezes** → self-refresh was not the (whole) cause. Escalate below.

---

## Escalation path if `0x410` does NOT fix it

Try these roughly in order; change one thing at a time and note the result.

1. **Widen the display-debug mask** — also disable stutter (another idle/clock-switch hang source):
   `amdgpu.dcdebugmask=0x412`  (0x2 = disable stutter, on top of PSR+Replay)

2. **Refresh firmware & kernel** — on silicon this new, the real long-term fix is often updated GPU microcode / a newer kernel:
   ```
   sudo apt update && sudo apt full-upgrade
   sudo apt install --reinstall linux-firmware
   ```
   Then check `dmesg | grep -i firmware` for the amdgpu blob versions loading, and reboot.

3. **Capture a freeze live** — from a TTY the instant it hangs, before rebooting:
   ```
   sudo dmesg | tail -100 > ~/freeze-$(date +%H%M).log
   journalctl -b 0 -k | tail -200 >> ~/freeze-$(date +%H%M).log
   ```
   Look for: `*ERROR* dc_`, `dmub`, `[drm] IP block`, `amdgpu: ... timeout`, `atombios`, VM page faults. Their presence/absence redirects the hypothesis (a ring timeout = compute hang, not PSR).

4. **Try disabling ASPM / PCIe power management** (a different freeze class that can mimic this):
   `amdgpu.aspm=0`  (append alongside the dcdebugmask param)

5. **Test a mainline/HWE kernel** if still on 7.0.0-14 — newer amdgpu often has the specific Krackan fix.

6. **Rule out compositor** — as a cheap experiment, disable XFCE compositing (Settings → Window Manager Tweaks → Compositor, or `xfconf-query -c xfwm4 -p /general/use_compositing -s false`). If freezes stop, it points at the xfwm4↔amdgpu present path rather than PSR.

### Recovery tricks when it freezes (before force-reboot)
Try cheapest first:
1. **Switch VT and back**: `Ctrl+Alt+F3` then `Ctrl+Alt+F2` (or F1/F7) — forces a modeset that may re-arm the display pipe **without killing the session** (apps survive).
2. **Restart the display manager** (CONFIRMED to work 2026-07-22): from a TTY, `sudo systemctl restart lightdm`. Gives a fresh working UI but **tears down the X session — all apps close.** Use only if the VT-switch trick fails.

Note: that a display-manager restart recovers the UI confirms the hang is a soft display-pipe wedge (fresh modeset fixes it), not a hard GPU lockup — see evidence table.

---

## Key files
- `scripts/fix-amdgpu-freeze.sh` — applies the mitigation (idempotent, self-elevating)
- `docs/freeze-diagnosis.md` — this file
- `/etc/default/grub.bak.*` — pre-change backups
