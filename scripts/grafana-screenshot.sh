#!/usr/bin/env bash
# grafana-screenshot.sh — pull a PNG of any Grafana dashboard or single panel.
#
# Renders via the grafana-image-renderer sidecar on PER630 (deployed 2026-04-16,
# part of /opt/homelab/grafana/docker-compose.yml).
#
# Usage:
#   grafana-screenshot.sh <dashboard-uid> <output.png> [--panel <id>] [--from <range>] [--width N] [--height N]
#
# Examples:
#   grafana-screenshot.sh hcc-nad-t748 nad.png
#   grafana-screenshot.sh hcc-nad-t748 nad-volume.png --panel 7
#   grafana-screenshot.sh idrac-dual-command-center dell.png --from now-6h --width 2560 --height 1440
#
# Auth: prompts for Grafana admin password unless GRAFANA_USER / GRAFANA_PASS env vars are set.

set -euo pipefail

GRAFANA_HOST="${GRAFANA_HOST:-grafana.home}"
WIDTH=1920
HEIGHT=2400
FROM="now-1h"
TO="now"
TZ="${TZ:-America/Toronto}"
PANEL=""
KIOSK="true"
THEME="dark"

UID_ARG=""
OUT_ARG=""

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --panel)  PANEL="$2"; shift 2 ;;
    --from)   FROM="$2"; shift 2 ;;
    --to)     TO="$2"; shift 2 ;;
    --width)  WIDTH="$2"; shift 2 ;;
    --height) HEIGHT="$2"; shift 2 ;;
    --theme)  THEME="$2"; shift 2 ;;
    -h|--help) usage ;;
    *)
      if [ -z "$UID_ARG" ]; then UID_ARG="$1"
      elif [ -z "$OUT_ARG" ]; then OUT_ARG="$1"
      else echo "Unexpected arg: $1" >&2; usage
      fi
      shift ;;
  esac
done

[ -z "$UID_ARG" ] || [ -z "$OUT_ARG" ] && usage

USER_NAME="${GRAFANA_USER:-admin}"
# Auth resolution order:
#   1. $GRAFANA_PASS env (CI / shell scripting)
#   2. ~/.config/techx-os/grafana-pass (user file, chmod 600 — drop the
#      password here once and unattended regens just work)
#   3. interactive prompt
PASS_FILE="${HOME}/.config/techx-os/grafana-pass"
if [ -z "${GRAFANA_PASS:-}" ] && [ -r "$PASS_FILE" ]; then
  GRAFANA_PASS="$(head -n1 "$PASS_FILE")"
fi
if [ -z "${GRAFANA_PASS:-}" ]; then
  read -rsp "Grafana password for ${USER_NAME}: " GRAFANA_PASS
  echo
fi

# Build the URL
URL="https://${GRAFANA_HOST}/render/d/${UID_ARG}?orgId=1&from=${FROM}&to=${TO}&tz=${TZ}&width=${WIDTH}&height=${HEIGHT}&theme=${THEME}&kiosk=${KIOSK}"
if [ -n "$PANEL" ]; then
  # Single-panel render uses /render/d-solo/<uid>
  URL="https://${GRAFANA_HOST}/render/d-solo/${UID_ARG}?orgId=1&from=${FROM}&to=${TO}&tz=${TZ}&width=${WIDTH}&height=${HEIGHT}&theme=${THEME}&panelId=${PANEL}"
fi

echo "→ Rendering ${UID_ARG}${PANEL:+ (panel ${PANEL})} ${WIDTH}x${HEIGHT} from ${FROM} → ${OUT_ARG}"

# -k: skip TLS verify (LAN cert)
# --max-time 60: rendering can be slow for large dashboards
HTTP_CODE=$(curl -sk -u "${USER_NAME}:${GRAFANA_PASS}" --max-time 60 \
  -w "%{http_code}" -o "$OUT_ARG" "$URL")

if [ "$HTTP_CODE" != "200" ]; then
  echo "✗ Failed: HTTP ${HTTP_CODE}" >&2
  echo "  Response body:" >&2
  cat "$OUT_ARG" >&2
  rm -f "$OUT_ARG"
  exit 1
fi

SIZE=$(stat -c%s "$OUT_ARG")
echo "✓ Saved ${OUT_ARG} (${SIZE} bytes)"
