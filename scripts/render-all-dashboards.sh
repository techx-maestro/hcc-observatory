#!/usr/bin/env bash
# render-all-dashboards.sh — render every HCC dashboard to PNG via the
# grafana-image-renderer sidecar.
#
# Usage: ./scripts/render-all-dashboards.sh [output-dir]
#   Default output dir: docs/screenshots/

set -euo pipefail

OUT_DIR="${1:-docs/screenshots}"
mkdir -p "$OUT_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auth resolution mirrors grafana-screenshot.sh (env → pass file → prompt).
PASS_FILE="${HOME}/.config/techx-os/grafana-pass"
if [ -z "${GRAFANA_PASS:-}" ] && [ -r "$PASS_FILE" ]; then
  GRAFANA_PASS="$(head -n1 "$PASS_FILE")"
fi
if [ -z "${GRAFANA_PASS:-}" ]; then
  read -rsp "Grafana password for admin: " GRAFANA_PASS
  echo
fi
export GRAFANA_PASS
export GRAFANA_USER="${GRAFANA_USER:-admin}"

# name (display/filename order) → uid
names=(
  01-nad-t748
  02-dell-servers
  03-mikrotik-router
  04-rpi-monitor
  05-ai-ollama
  06-homelab-logs
  07-prometheus-health
)
uids=(
  hcc-nad-t748
  idrac-dual-command-center
  mikrotik-mktxp
  rpi-unified
  hcc-ai-ollama
  homelab-log-intelligence
  prometheus-health
)

for i in "${!names[@]}"; do
  out="$OUT_DIR/${names[$i]}.png"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "[$((i+1))/${#names[@]}]  ${names[$i]}  (uid=${uids[$i]})"
  "$SCRIPT_DIR/grafana-screenshot.sh" "${uids[$i]}" "$out" --width 2200 --height 3200 || {
    echo "✗ Failed rendering ${names[$i]} — continuing"
    continue
  }
done

echo
echo "✓ Done. Output in $OUT_DIR/"
ls -lh "$OUT_DIR"
