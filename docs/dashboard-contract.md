# Dashboard Contract

Every HCC Observatory dashboard is bound by the rules below. This document
is the source of truth — not the JSON, not the UI, not Grafana defaults.
When a dashboard drifts, it's fixed against this file.

## Palette (locked)

HCC is a cyan-dominant brand. The palette tracks the physical space — the
user's workspace is lit by cyan LED strips with one magenta focal point, and
the dashboards are meant to read like a JARVIS/TARS console in that room.

| Hex        | Role                                   | Share  |
|------------|----------------------------------------|--------|
| `#00B7FF`  | Primary cyan                           | ~70%   |
| `#88C0D0`  | Frost — secondary, muted               | ~15%   |
| `#B986F2`  | Violet — accent                        | ~8%    |
| `#FF00B2`  | Magenta — rare warm focal point        | ~5%    |
| `#BF616A`  | Muted red — critical-only              | <2%    |

**Banned:**
- Sage green
- Mustard yellow
- Standalone orange
- Any default Grafana palette (`classic`, `green-yellow-red`, etc.) without
  explicit thresholds that route through the locked palette

**One-desk-lamp rule.** At most one magenta focal point per dashboard.
Magenta is reserved for the single most important live-state panel —
typically the one panel a user would look at first. Everything else is
cyan/frost/violet.

## Typography & icons

- Panel titles use emoji as section markers (🎛, ⚡, 🌡, 💾, 🔒, 📡).
  These are load-bearing: they scan faster than text when the dashboard
  is glanced at from across the room.
- Section **row** panels carry the section icon + ALL-CAPS title.
- Individual stat/gauge panels stay short — 2–3 words max. Long titles
  wrap and break the grid rhythm.

## Panel type guidance

| Situation | Preferred type |
|-----------|----------------|
| Single live value, small cardinality | `stat` |
| Single value that should be read as a percentage or dial | `gauge` |
| Many values over time | `timeseries` |
| Categorical state over time (source, mute, up/down) | `status-history` or `state-timeline` |
| Tabular data (inventory, top-N) | `table` |
| Top-N with magnitude | `bargauge` |
| Distribution snapshot | `piechart` only when the categories sum to something meaningful (e.g. DNS query types) |

**Banned panel types:**
- `graph` (legacy — replaced by `timeseries` in Grafana 9+)
- `singlestat` (legacy — replaced by `stat`)
- Any panel that can't have thresholds from the locked palette applied

## Row structure

Every dashboard opens with a `📡 NETWORK STATUS` row — a shared four-panel
strip across the top that gives a consistent landing experience. This is
the "am I looking at a live system" sanity check; if any of those four
panels are stale, every other panel is suspect.

After that, rows are organized by subsystem, largest-blast-radius first:

1. **Overview / live state** — what's happening right now
2. **Resource health** — CPU / RAM / temp / power
3. **Inventory** — what's installed, what's connected
4. **History** — longer time-range trends
5. **Logs** (if applicable) — searchable stream at the bottom

## Variable conventions

- `prom_ds` — type `datasource`, query filter `prometheus`. Every Prometheus
  panel references `${prom_ds}`, never a hardcoded UID.
- `loki_ds` — same pattern for Loki-backed panels.
- `interval` — multi-select `5m,15m,1h,6h,24h,7d`, default `24h`. Used as
  `[$interval]` in range vectors.
- Host-scoped dashboards use `host` or `instance` variables with `All`
  enabled, so the same dashboard renders for a single host or the fleet.

## Links

Every dashboard includes a `links` block for cross-navigation. At minimum:
- Self-link disabled (prevents the infinite "same dashboard" link trap)
- Links to peer dashboards that share a host or subsystem
- External links (NAD remote UI, iDRAC web UI) open in a new tab with
  `targetBlank: true`

## Edit discipline

- File in `provisioning/dashboards/json/` is source of truth.
- UI edits persist to the Grafana DB but are overwritten on next file rescan
  (30s). Use them for experimentation only — export JSON back to file
  before closing the session, or lose the change.
- JSON diffs are reviewed on every PR. Cosmetic drift (random UID changes,
  reordered `targets`, changed `$ref` to `${DS_PROMETHEUS}`) is rejected;
  semantic changes only.

## When in doubt

Ask: "Would a user glancing at this from across the room, at arm's length,
in a cyan-lit room, immediately know whether the system is healthy?"

If yes: ship it.
If no: the dashboard is wrong, not the user.
