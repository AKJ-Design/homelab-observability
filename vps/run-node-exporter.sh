#!/usr/bin/env bash
# Run node-exporter on the Oracle VPS, bound to the Tailscale interface ONLY,
# so it's reachable from the tailnet (e.g. home Prometheus) but NOT from the
# public internet. Compose v2 wasn't available on this box, so we use plain
# `docker run` instead of the compose file.
#
# Usage:  sudo bash run-node-exporter.sh
set -euo pipefail

# The VPS's own Tailscale IP  (find it with: tailscale ip -4)
TAILSCALE_IP="100.123.209.36"

docker rm -f node-exporter 2>/dev/null || true
docker run -d --name node-exporter --restart unless-stopped \
  --net host --pid host \
  -v /:/host:ro,rslave \
  prom/node-exporter:v1.8.2 \
  --path.rootfs=/host \
  --web.listen-address="${TAILSCALE_IP}:9100"

echo "node-exporter is now bound to ${TAILSCALE_IP}:9100 (tailnet only)."
echo "Test from the VPS with:  curl -s ${TAILSCALE_IP}:9100/metrics | head -3"
