# Architecture

HCC Observatory is the observability spine of the Home Control Center. It
ingests metrics and logs from every asset in the homelab — routers,
rack servers, Raspberry Pi, NAD audio/video receiver, AI inference box —
and renders them through seven curated Grafana dashboards served under a
single brand-locked palette.

## Stack topology

```
                    ┌───────────────────────────────────────┐
                    │            CADDY (LAN TLS)            │
                    │  grafana.home → 10.20.20.3:3000       │
                    └───────────────┬───────────────────────┘
                                    │
        ┌───────────────────────────┴───────────────────────────┐
        │                     PER630 (Dell R630)                │
        │                     10.20.20.3                        │
        │  ┌──────────────────────┐   ┌──────────────────────┐  │
        │  │   grafana:latest     │◀─▶│ grafana-image-       │  │
        │  │   (file-provisioned) │   │ renderer:latest      │  │
        │  │   port 3000          │   │ port 8081            │  │
        │  └──────────┬───────────┘   └──────────────────────┘  │
        │             │ datasource: http://prometheus:9090      │
        │             │             http://loki:3100            │
        │  ┌──────────▼───────────┐   ┌──────────────────────┐  │
        │  │  prometheus:latest   │   │  loki:latest         │  │
        │  │  (scrape config +    │   │  (log backend)       │  │
        │  │   alert rules in     │   │                      │  │
        │  │   /etc/prometheus)   │   │                      │  │
        │  └──────────────────────┘   └──────────▲───────────┘  │
        └─────────────┬───────────────────────────┼─────────────┘
                      │                           │
                      │ scrapes                   │ push (promtail)
                      │                           │
    ┌─────────────────┼───────────────────────────┼─────────────────┐
    │                 │                           │                 │
┌───▼────────┐  ┌─────▼──────┐  ┌──────────┐  ┌──▼────────┐  ┌─────▼─────┐
│ MikroTik   │  │ Dell iDRAC │  │ node_    │  │ ollama-   │  │ NAD       │
│ RB3011     │  │ PER630 +   │  │ exporter │  │ exporter  │  │ RS-232    │
│            │  │ PER730XD   │  │ (RPi +   │  │ PER730XD  │  │ service   │
│ mktxp +    │  │ SNMP +     │  │  PER630) │  │ (GTX 1070)│  │ RPi:3082  │
│ snmp-exp   │  │ Redfish    │  │          │  │           │  │           │
└────────────┘  └────────────┘  └──────────┘  └───────────┘  └───────────┘
    10.10.1.1     iDRAC VLAN     10.40.40.2    10.10.10.2      10.40.40.2
                                  10.20.20.2
```

## Data flow

1. **Metrics (pull).** Prometheus scrapes every target listed in
   [`compose/prometheus.yml`](../compose/prometheus.yml) on a 15s interval.
   Exporters are intentionally diverse — vendor-native (mktxp, pihole-exporter,
   idrac_exporter), SNMP proxies for the RouterOS MIB and Dell's iDRAC MIB,
   generic node_exporters, and a custom Python `ollama-exporter` that wraps
   both the Ollama HTTP API and nvidia-smi into a single scrape target.

2. **Logs (push).** `promtail` runs on every machine that generates
   interesting logs (RouterOS syslog relay, iDRAC syslog relay via RFC3164
   on the RPi) and pushes to Loki on PER630. Loki retention is 30d,
   indexed by `{host,job,severity}`.

3. **Datasource binding.** Every dashboard in
   [`provisioning/dashboards/json/`](../provisioning/dashboards/json) uses a
   `prom_ds` / `loki_ds` variable typed as `datasource`, not a hard-coded UID.
   This keeps the JSONs portable — they work against any Prometheus/Loki
   datasource without re-templating.

4. **Presentation.** Grafana auto-provisions dashboards from file
   (`updateIntervalSeconds: 30`), so edits to JSON in this repo land in the
   UI within half a minute on deploy. `allowUiUpdates: true` is tolerated —
   the file is still source of truth and overwrites on rescan.

5. **Rendering.** The `grafana-image-renderer` sidecar (same docker network,
   shared `GF_RENDERING_RENDERER_TOKEN`) serves `/render/d/<uid>` and
   `/render/d-solo/<uid>` for headless PNG export. This is how every
   screenshot in `docs/screenshots/` is produced — see
   [`scripts/render-all-dashboards.sh`](../scripts/render-all-dashboards.sh).

## Why this shape

- **File-provisioned over API-managed.** Dashboards live in git, not in the
  Grafana DB. Rebuilds are reproducible; `docker compose down && up -d`
  restores the full pane set.
- **Prometheus retention on-box.** 1 year of metrics on PER630's bind mount.
  No Thanos, no remote-write — a homelab doesn't need cross-cluster
  federation and the extra moving parts would just be failure surface.
- **Loki over ELK.** Loki's label-based indexing is a natural fit for
  structured syslog, and the storage footprint is ~10× smaller than
  Elasticsearch for the same query set.
- **Renderer as a sidecar, not a service dependency.** If the renderer
  crashes, dashboards still load in the browser. Only PNG export breaks.
  (The failure mode added in 2026-04-16 — Grafana refusing to boot with
  the default renderer token — is explicitly called out in
  [`.env.example`](../.env.example).)

## Exporters inventory

| Exporter | Target | Surface | Notes |
|----------|--------|---------|-------|
| `mktxp` | RB3011 via API | RouterOS metrics (CPU, PoE, queues, firewall, DHCP, CAPsMAN) | Richer than SNMP alone |
| `snmp-exporter` (RouterOS module) | RB3011 via SNMPv2 | Interface counters, uptime | Overlaps mktxp; used for a handful of OIDs mktxp doesn't expose |
| `snmp-exporter` (dell_idrac module) | iDRAC on PER630 + PER730XD | Sensors, fans, PSUs, storage | First-scrape sometimes shows `unknown` |
| `idrac_exporter` (mrlhansen) | iDRAC Redfish API | Drive detail, link speeds, event log, power stats | Complements SNMP with things Redfish has that SNMP doesn't |
| `node_exporter` | RPi + PER630 | CPU, RAM, disk, network, filesystem | Standard |
| `ollama-exporter` (custom) | PER730XD:9401 | Ollama service status, model memory, GPU via nvidia-smi | Python, systemd unit |
| `pihole-exporter` | RPi container | DNS queries, block rates, top domains | v1 API |
| `hcc-nad-rs232` | RPi:3082 | NAD T748 state from RS-232 | Custom — see `hcc-nad-rs232` repo |
| `prometheus` | self | All `prometheus_*` internals | Powers scrape-health dashboard |

## Failure modes and their dashboards

| Failure | Dashboard that will catch it first |
|---------|-----------------------------------|
| Dell PSU degraded / RAID battery dead | Dell Servers — Command Center |
| iDRAC event log spike | Homelab Logs — iDRAC panels |
| Router CPU sustained >80% / firewall hit burst | MikroTik Router |
| NAD RS-232 link flap | NAD T748 — RS-232 panels |
| GPU OOM during inference | AI Command Center — VRAM panels |
| Pi-hole blocking rate collapse | RPi Monitor — Pi-hole section |
| Prometheus self-scrape lag or tardy scrape | Prometheus — Scrape Health |
