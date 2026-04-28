# Multi-host displays

Two TechX OS machines &mdash; the PER730XD desk workstation and the TX1Y4
ThinkPad &mdash; share a single LG SDQHD monitor over DisplayPort, plus
their own dedicated panels (an LG HDR WQHD ultrawide on the desk, the
laptop's internal eDP). KDE Plasma / kscreen handles dynamic display
topology cleanly out of the box. Hyprland's static `monitor =` rules
can't conditionally apply by current EDID mode. This deep-dive covers
the three daemons and one eww popout that close that gap, plus the
**HCC monitor widget** that lets you control every panel in the rig
from a single popout &mdash; including the laptop's screen wirelessly.

**Source:** [techx-os/docs/multi-host-displays.md](https://github.com/techx-maestro/techx-os/blob/main/docs/multi-host-displays.md) (private)
**Stack:** Bash &middot; ddcutil &middot; brightnessctl &middot; Hyprland &middot; eww (yuck + SCSS) &middot; SSH
**Deploys to:** PER730XD (owner / master sensor host) and TX1Y4 (guest)
**Lines of code:** ~140 (watcher) + ~80 (ambient mirror) + ~270 (CLI) + ~110 (eww popout)

## What it does

Three small daemons + one CLI close the gaps Hyprland leaves vs. KDE/kscreen:

- **`techx-monitor-watcher`** &mdash; auto-toggles each host's DP-1 between
  PbP (2560&times;1440) and DualUp (2560&times;2880) when the LG's OSD
  button is pressed. No software trigger needed; the daemon polls the
  EDID on the owner host and SSHes the resolved state to the guest.
- **`techx-ambient-sync`** &mdash; reads the LG SDQHD's built-in ambient
  light sensor via DDC/CI VCP `0x10` and mirrors the value to every
  other panel in the rig (LG ultrawide via DDC, TX laptop's internal
  panel via SSH + `brightnessctl`).
- **`techx-monitor-ctl`** &mdash; unified CLI that wraps ddcutil, sysfs
  backlight, and the SSH+brightnessctl path behind one JSON shape.
  Speaks `status`, `set <id> <prop> <value>`, `ambient-toggle`.
- **HCC monitor widget** (eww popout) &mdash; a `SUPER+M` popout listing
  every detected panel as a row with brightness/volume +/- chips and a
  bottom ambient-toggle. The novelty: TX1Y4's laptop screen appears as
  a row in PER's popout. **The DP cable doesn't have to be plugged
  in.** Brightness changes go SSH &rarr; brightnessctl &rarr;
  `/sys/class/backlight` on TX, all over WiFi.

## Transport matrix

| Display id     | Transport | Get/Set path                                   |
|----------------|-----------|------------------------------------------------|
| 1 (DP-1 SDQHD) | `ddc`     | `ddcutil --bus 4 ...`                          |
| 2 (DP-2 WQHD)  | `ddc`     | `ddcutil --bus 5 ...`                          |
| `internal`     | `sysfs`   | `brightnessctl --device=intel_backlight`       |
| `tx-internal`  | `ssh`     | `ssh xbc4000@10.60.60.202 brightnessctl ...`   |

The eww row template renders identically regardless of transport &mdash;
keyed off `id` and `has_volume` from the JSON.

## The three quirks worth keeping in memory

### 1. Hyprland atomic-check rejection (PER only)

Applying `DP-1=2560x2880` while DP-2 is at `3440x1440@75 10-bit` fails
hyprland's atomic-check with `Invalid argument` and silently falls
DP-1 back to `1920x1080`. KDE doesn't hit this because kscreen
serializes modesets &mdash; Hyprland commits in one atomic batch.

**Workaround:** when the owner needs to apply `2560x2880`, the watcher
drops DP-2 to `3440x1440@60 8-bit` &rarr; applies DP-1 &rarr; restores
DP-2 to `@75 10-bit`. Total ~3-5 s. Customer doesn't see the dance.

### 2. Cross-host EDID is unreliable

The LG advertises `2560x1440` to TX whether PbP is on or off, so the
guest host can't infer the master's display state from its own EDID.
The watcher solves this with a tiny cross-host SSH signal: PER writes
the resolved state to `~/.local/share/techx-os/lg-pbp-state` (atomic
via `mktemp` + `mv`); TX SSHes in, reads it, decides. SSH timeout 3 s;
on failure, TX defaults to `DP-1, disable` &mdash; safer than guessing.

### 3. The eww `@charset` trap

eww bundles grass-rs as its SCSS compiler. Current grass-rs emits a
leading `@charset "UTF-8";` directive into the compiled CSS, and eww's
GTK loader then rejects it &mdash; silently falling **every** popout
back to no-CSS (black void with cyan outline only). Workaround: pre-
compile `eww.scss` to `eww.css` externally with `grass`, strip the
`@charset` line via `tail -n +2`, ship the resulting `eww.css`. Eww
uses `eww.css` if both files exist; rename the source to `eww.scss.src`
so eww doesn't try to recompile it itself.

## Performance design

The first cut was unusable &mdash; `status` took 82 s and `set` took
9.8 s &mdash; because `ddcutil --display N` does a full bus rescan with
`EACCES` retries on every non-display i2c bus on the box. The current
pipeline lands clicks in &le; 500 ms end-to-end:

- `--bus N` not `--display N` for ddcutil &rarr; **28&times; faster**
  (skips per-call EACCES retries on i2c-7/8 / non-display buses).
- `--sleep-multiplier 0.1` &rarr; another **1.6&times;**.
- Status cache at `$XDG_RUNTIME_DIR/techx-monitor-ctl/status.json`,
  TTL 5 s, **stale-while-revalidate**: returns cached JSON instantly
  even if stale, kicks a flock-guarded background refresh only when
  expired. Eww's 500 ms polls never block on i2c.
- **Optimistic in-place cache update on `set`** &mdash; the new value
  lands in the cache before the ddcutil/SSH call dispatches; eww's
  next poll reflects the change without waiting on hardware. Atomic
  via `mv`.
- **Detached, per-bus-flock background dispatch on `set`** &mdash; the
  CLI returns in ~40 ms; the actual ddcutil/SSH runs in a setsid-
  detached subshell with `flock $CACHE_DIR/bus-N.lock` so rapid
  mash-clicks serialize without two concurrent setvcps interleaving on
  the bus (which the LG firmware silently drops).

End-to-end: click &rarr; UI updated in &le; 500 ms; hardware physically
changes ~ 0.3-1 s after.

## Why not just use kscreen?

KDE's kscreen is the inspiration. We don't run a full Plasma session on
these hosts (Hyprland is the daily WM), and kscreen depends on too much
of the Plasma stack to slot in cleanly. The watcher is ~140 lines of
bash; the ambient mirror is ~80; the CLI is ~270; the popout is ~110
lines of yuck + a few dozen lines of SCSS. Both daemons ship in the
TechX OS image, both run as user units, both are observable via
`journalctl --user`. They handle the two specific multi-host quirks of
this rig and nothing else.

## Cross-references

- `techx-monitor-watcher` lives at
  `files/skel/.local/bin/techx-monitor-watcher` in the techx-os repo.
- `techx-ambient-sync` + its systemd user unit (gated by
  `ConditionHost=PER730XD`) live at `files/usr/local/bin/` and
  `files/etc/systemd/user/`.
- `techx-monitor-ctl` lives at `files/usr/local/bin/techx-monitor-ctl`.
- The eww popout lives in `files/skel/.config/eww/eww.yuck` (see
  `defwindow monitor-card` + `defwidget monitor-row`).
- The full doc with all the dead-end DDC probes (`F4`-`FF`, `E0`-`EF`,
  `4D`-`4F`, `15` &mdash; none expose PbP toggle) is in the techx-os
  repo at `docs/multi-host-displays.md`.
