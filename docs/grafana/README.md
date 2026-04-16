# Grafana Stack

The metrics-visualization layer of HCC. Seven brand-locked dashboards,
file-provisioned from this repo, rendered against a Prometheus + Loki
backend running on PER630.

📐 **[Architecture](architecture.md)** — stack topology, data flow, exporter inventory
🎨 **[Dashboard Contract](dashboard-contract.md)** — palette, typography, and panel rules
📊 **[Dashboards](dashboards/)** — per-dashboard deep dives (7 files)

## The seven dashboards

| # | Dashboard | UID | Deep dive |
|---|-----------|-----|-----------|
| 1 | NAD T748v2 — RS-232 Command Center | `hcc-nad-t748` | [nad-t748-rs232.md](dashboards/nad-t748-rs232.md) |
| 2 | Dell Servers — iDRAC Command Center | `idrac-dual-command-center` | [dell-servers.md](dashboards/dell-servers.md) |
| 3 | MikroTik Router — RB3011 | `mikrotik-mktxp` | [mikrotik-router.md](dashboards/mikrotik-router.md) |
| 4 | Raspberry Pi — Monitoring Stack | `rpi-unified` | [rpi-monitor.md](dashboards/rpi-monitor.md) |
| 5 | AI Command Center — Ollama + GPU | `hcc-ai-ollama` | [ai-ollama.md](dashboards/ai-ollama.md) |
| 6 | Homelab Logs — Router & Servers | `homelab-log-intelligence` | [homelab-logs.md](dashboards/homelab-logs.md) |
| 7 | Prometheus — Scrape Health | `prometheus-health` | [prometheus-health.md](dashboards/prometheus-health.md) |

## Gallery

### 1. NAD T748v2 · RS-232 Command Center
![NAD T748](screenshots/01-nad-t748.png)

### 2. Dell Servers · iDRAC Command Center
![Dell iDRAC](screenshots/02-dell-servers.png)

### 3. MikroTik Router · RB3011
![MikroTik RB3011](screenshots/03-mikrotik-router.png)

### 4. Raspberry Pi · Monitoring Stack
![RPi Monitor](screenshots/04-rpi-monitor.png)

### 5. AI Command Center · Ollama + GPU
![AI Command Center](screenshots/05-ai-ollama.png)

### 6. Homelab Logs · Router & Servers
![Homelab Logs](screenshots/06-homelab-logs.png)

### 7. Prometheus · Scrape Health
![Prometheus Health](screenshots/07-prometheus-health.png)
