# Homelab Observability Stack

Prometheus + Grafana + node-exporter + cAdvisor + Bitcoin exporter for an
Umbrel mini PC, plus an Oracle VPS scraped remotely.

## Layout
```
observability-stack/
  docker-compose.yml            # the main stack (runs on Umbrel host)
  .env.example                  # copy to .env, fill Bitcoin RPC creds
  prometheus/prometheus.yml     # scrape config (edit VPS IP + Kuma key)
  grafana/provisioning/...      # auto-wires datasource + dashboard loader
  grafana/dashboards/overview.json
  vps/docker-compose.vps.yml    # runs on the Oracle VPS (node-exporter)
```

## 1. Deploy on the Umbrel mini PC
Copy this folder to the mini PC (`scp -r observability-stack umbrel@<lan-ip>:~/`),
then SSH in:
```bash
cd observability-stack
cp .env.example .env
nano .env            # fill Bitcoin RPC host/user/password
nano docker-compose.yml   # change GF_SECURITY_ADMIN_PASSWORD
docker compose up -d
docker compose ps
```
- Grafana:    http://<lan-ip>:3000  (admin / your password)
- Prometheus: http://<lan-ip>:9090  (Status -> Targets to see health)

If port 3000 or 9090 clashes with an Umbrel app, change the left side of the
`ports:` mapping (e.g. `"3030:3000"`).

## 2. Wiring up the Bitcoin exporter
The exporter needs to reach bitcoind's RPC (port 8332).

1. Get credentials: Umbrel UI -> **Bitcoin** app -> settings / "Connect"
   section shows RPC user + password.
2. Find the host/port that's reachable. On the mini PC:
   ```bash
   sudo ss -tlnp | grep 8332      # is RPC published on the host?
   ```
   - If it shows `0.0.0.0:8332` or `<lan-ip>:8332`, set `BITCOIN_RPC_HOST`
     in `.env` to the LAN IP.
   - If it only shows a docker-internal bind, attach the exporter to
     Umbrel's network instead (see "Advanced" below).
3. `docker compose up -d bitcoin-exporter` then check:
   ```bash
   curl -s localhost:9332/metrics | grep bitcoin_blocks
   ```

### Advanced: join Umbrel's Docker network
If RPC isn't on the host, find Umbrel's network and bitcoind's container name:
```bash
docker network ls
docker ps --format '{{.Names}}' | grep -i bitcoin
```
Then add to the `bitcoin-exporter` service in docker-compose.yml:
```yaml
    networks: [umbrel_main_network]     # name from `docker network ls`
# and at the bottom of the file:
networks:
  umbrel_main_network:
    external: true
```
Set `BITCOIN_RPC_HOST` to the bitcoind container name.

## 3. Add the Oracle VPS
Recommended: put both machines on a **Tailscale** tailnet, then Prometheus
scrapes the VPS's `100.x` address — nothing exposed to the public internet.

On the VPS:
```bash
# install tailscale + docker, then:
scp -r vps umbrel@... # or just recreate vps/docker-compose.vps.yml there
cd vps && docker compose -f docker-compose.vps.yml up -d
```
Then in `prometheus/prometheus.yml` replace `100.100.100.100` with the VPS's
Tailscale IP for both the `vps-node` and `uptime-kuma` jobs.

### Uptime Kuma metrics
Kuma already exposes Prometheus metrics at `/metrics`, protected by an API key.
1. Kuma -> Settings -> **API Keys** -> add key -> copy it.
2. Paste it into `prometheus.yml` under the `uptime-kuma` job
   (`basic_auth.password`). Username stays blank.

## 4. Reload after editing prometheus.yml
```bash
curl -X POST http://localhost:9090/-/reload
```
Then check **Prometheus -> Status -> Targets**: every target should be `UP`.

## 5. Import ready-made exporter dashboards (optional but recommended)
In Grafana: **Dashboards -> New -> Import**, paste an ID, pick the Prometheus
datasource:
- `1860`  — Node Exporter Full (host deep-dive)
- `14282` — cAdvisor (per-container deep-dive)

Your hand-built **Homelab Overview** loads automatically.
