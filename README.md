# HCC Observatory

**The observability spine of the Home Control Center.**
Seven brand-locked Grafana dashboards, a Prometheus + Loki backend, and
the full provisioning pipeline — all in one repo, all in one look.

---

![NAD T748 Dashboard](docs/screenshots/01-nad-t748.png)

---

## What is this?

HCC (Home Control Center) is a multi-device home platform by
[TechX Maestro](https://techxmaestro.com). This repo is the metrics
layer: every rack server, router port, DNS query, GPU temperature, and
RS-232 volume tweak, rendered through one cyan-dominant palette so every
pane looks like the same console.

It runs on a Dell PowerEdge R630 (PER630, `10.20.20.3`) and watches:

- 2 × Dell rack servers (PER630 + PER730XD) via **iDRAC SNMP + Redfish**
- 1 × MikroTik RB3011 via **mktxp + snmp-exporter (RouterOS module)**
- 1 × Raspberry Pi running Pi-hole, promtail, 15+ containers
- 1 × NAD T748v2 A/V receiver via **custom RS-232 → Prometheus gateway**
- 1 × Nvidia GPU running Ollama via **custom `ollama-exporter`**
- All log traffic via **promtail → Loki** (30d retention)

## Stack

| Layer | Tool | Notes |
|-------|------|-------|
| Metrics ingest | **Prometheus** | 1y retention, 15s scrape, ~18k series |
| Log ingest | **Loki** | 30d retention, RFC3164 via promtail |
| Visualization | **Grafana** (latest) | File-provisioned, 7 dashboards |
| Headless render | **grafana-image-renderer** | Sidecar, shared auth token |
| Reverse proxy | **Caddy** (LAN TLS) | `grafana.home` → 10.20.20.3:3000 |
| Exporters | mktxp · snmp-exporter · idrac_exporter · node_exporter · ollama-exporter · pihole-exporter · hcc-nad-rs232 | |

Full architecture walkthrough: [`docs/architecture.md`](docs/architecture.md).

## The seven dashboards

Every screenshot below links to a deep-dive explaining every panel,
every data source, and every engineering decision.

### 1 · [NAD T748v2 · RS-232 Command Center](docs/dashboards/nad-t748-rs232.md)
Turning a 2009-vintage A/V receiver into a fully instrumented IoT device
over its proprietary serial port. Live state, volume history, source
timeline, RS-232 link health.

![NAD T748](docs/screenshots/01-nad-t748.png)

---

### 2 · [Dell Servers — iDRAC Command Center](docs/dashboards/dell-servers.md)
Dual-host dashboard for PER630 and PER730XD. Every sensor, fan, PSU,
drive, DIMM, NIC, and SEL entry. SNMP for speed, Redfish for depth,
Loki for the iDRAC syslog stream.

![Dell iDRAC](docs/screenshots/02-dell-servers.png)

---

### 3 · [MikroTik Router — RB3011](docs/dashboards/mikrotik-router.md)
The core router. System, DHCP, network, firewall, netwatch, CAPsMAN
wireless, and mktxp exporter self-metrics. Per-interface repeating
rows with multi-select variable.

![MikroTik RB3011](docs/screenshots/03-mikrotik-router.png)

---

### 4 · [Raspberry Pi — Monitoring Stack](docs/dashboards/rpi-monitor.md)
The Pi is three things at once — system host, container host, DNS
resolver. This dashboard is three dashboards in one: node_exporter,
cadvisor, and pihole-exporter fused into a coherent view.

![RPi Monitor](docs/screenshots/04-rpi-monitor.png)

---

### 5 · [AI Command Center — Ollama + GPU](docs/dashboards/ai-ollama.md)
Ollama model inventory, active inference memory allocation, and full
GPU telemetry (utilization, VRAM, power, clocks, temperature, fans)
via a custom Python exporter that fuses the Ollama API with
`nvidia-smi`.

![AI Command Center](docs/screenshots/05-ai-ollama.png)

---

### 6 · [Homelab Logs — Router & Servers](docs/dashboards/homelab-logs.md)
Unified log intelligence. Every RouterOS syslog topic and every iDRAC
event, searchable, filterable, correlated. LogQL metric queries for
the stat panels; raw streams at the bottom of every row.

![Homelab Logs](docs/screenshots/06-homelab-logs.png)

---

### 7 · [Prometheus — Scrape Health](docs/dashboards/prometheus-health.md)
The meta-dashboard. Prometheus watching Prometheus. If this one goes
weird, everything else is suspect until it clears.

![Prometheus Health](docs/screenshots/07-prometheus-health.png)

---

## Design philosophy

HCC is a cyan-dominant brand — the dashboards are meant to read like a
JARVIS/TARS console in a room lit by cyan LED strips with one magenta
focal point. Every panel obeys the
[Dashboard Contract](docs/dashboard-contract.md): locked 5-color palette,
one magenta "desk lamp" per dashboard, no Grafana-default classic
palettes, emoji section markers as load-bearing visual anchors.

| Hex | Role | Share |
|-----|------|-------|
| `#00B7FF` | Primary cyan | 70% |
| `#88C0D0` | Frost | 15% |
| `#B986F2` | Violet | 8% |
| `#FF00B2` | Magenta (focal point) | 5% |
| `#BF616A` | Muted red (critical only) | <2% |

Banned: sage green, mustard yellow, standalone orange, Grafana's
`palette-classic`, `green-yellow-red`, or any threshold mode without
explicit hex values from the locked palette.

## Running the stack

**Prerequisites:** Docker, a `homelab-monitoring` external network,
bind-mount directories for Grafana and Prometheus data.

```sh
# 1. Set the renderer token (CRITICAL — Grafana refuses to boot without it)
cp .env.example .env
echo "GRAFANA_RENDERER_TOKEN=$(openssl rand -hex 32)" > .env
chmod 600 .env

# 2. Bring up the stack
docker compose -f compose/grafana.yml up -d

# 3. Verify
curl -sk https://grafana.home/api/health
```

See [`compose/grafana.yml`](compose/grafana.yml) for the full compose
file and [`.env.example`](.env.example) for environment variables.

## Rendering screenshots

All screenshots in this README are produced headlessly by the sidecar
renderer:

```sh
# Render all 7 dashboards into docs/screenshots/
./scripts/render-all-dashboards.sh

# Render a single dashboard
./scripts/grafana-screenshot.sh hcc-nad-t748 out.png

# Render a specific panel
./scripts/grafana-screenshot.sh hcc-nad-t748 out.png --panel 7
```

The renderer is a sidecar container sharing an auth token with Grafana
over a private Docker network. Full scripts:
[`scripts/grafana-screenshot.sh`](scripts/grafana-screenshot.sh),
[`scripts/render-all-dashboards.sh`](scripts/render-all-dashboards.sh).

## Repository layout

```
hcc-observatory/
├── README.md                           # this file
├── LICENSE                             # proprietary
├── NOTICE.md                           # trademarks
├── .env.example                        # renderer token template
├── compose/
│   └── grafana.yml                     # grafana + renderer stack
├── provisioning/
│   ├── dashboards/
│   │   ├── homelab.yml                 # provider config (rescan 30s)
│   │   └── json/                       # 7 dashboard JSONs
│   │       ├── nad-t748-rs232.json
│   │       ├── dell-servers.json
│   │       ├── mikrotik-router.json
│   │       ├── rpi-monitor.json
│   │       ├── ai-ollama.json
│   │       ├── homelab-logs.json
│   │       └── prometheus-health.json
│   └── datasources/
│       └── prometheus.yml              # prom + loki datasources
├── alerts/
│   ├── alerts-homelab.yml              # Prometheus alert rules
│   └── alerts-pihole.yml
├── scripts/
│   ├── grafana-screenshot.sh           # single-panel / dashboard PNG
│   └── render-all-dashboards.sh        # batch all 7
└── docs/
    ├── architecture.md
    ├── dashboard-contract.md
    ├── screenshots/                    # 7 rendered PNGs
    └── dashboards/                     # 7 per-dashboard deep dives
```

## Licensing

All source, configuration, and visual design in this repo are the
proprietary property of TechX Maestro. See [LICENSE](LICENSE) and
[NOTICE.md](NOTICE.md).

## Credits

- **Grafana Labs** — Grafana and grafana-image-renderer
- **mrlhansen/idrac_exporter** — Redfish-based iDRAC metrics
- **akpw/mktxp** — RouterOS native metrics exporter
- **prometheus/snmp_exporter** — the workhorse for RouterOS + iDRAC MIBs
- **ekofr/pihole-exporter** — Pi-hole v1 API exporter
- **NAD Electronics** — for documenting the T748 RS-232 protocol, even
  if 2009-style

---

Part of the [TechX Maestro](https://techxmaestro.com) HCC product line.
