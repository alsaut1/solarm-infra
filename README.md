# solarm-infra

Infrastructure automation and monitoring for [solarm.app](https://solarm.app) — Solana RPC and Yellowstone gRPC node operations.

## Layout

```
relay01/            monitoring, metrics collection, reverse proxy
  scripts/          collect.sh, status.sh, nodewatch.sh (Telegram alerting)
  dashboard/        Rust/axum dashboard with live charts
  proxy/            Rust/axum RPC proxy
solane01/           Agave validator node (non-voting RPC)
  config/           run-validator.sh, geyser-config.json
  node-exporter/    Rust Prometheus exporter
  scripts/          rpcstat.sh — per-IP RPC method breakdown
docs/               operational notes
```

## Stack

- Agave validator 4.2.2 (non-voting RPC node)
- Yellowstone gRPC (Geyser plugin) v15.1.2
- Rust, axum, tokio
- Prometheus metrics, bash ops scripts
- Ubuntu 22.04

## Components

### relay01

**`collect.sh`** — pulls 16 metric columns from the node exporter and the
Yellowstone Prometheus endpoint into a CSV time series.

**`status.sh`** — terminal dashboard: gRPC/RPC/pubsub connections, send queue
size, replay timing.

**`nodewatch.sh`** — health monitor with Telegram alerting. Checks `getHealth`,
slot progression (double sample with 15s gap), finalization lag, network lag and
validator RSS. State file prevents alert spam — notifications fire on transitions
only. Runs from cron every 5 minutes.

**`dashboard/`** — axum HTTP server on port 9200 serving live canvas charts over
the collected metrics: six series, threshold coloring, three time windows.

**`proxy/`** — axum reverse proxy in front of the node's RPC port. Currently
`GET /health`, `GET /test`, `POST /rpc`.

### solane01

**`node-exporter/`** — Rust Prometheus exporter exposing metrics the validator
does not publish itself: `rpc_connections`, `pubsub_connections`,
`pubsub_sendq_bytes`, `replay_elapsed_us`, `validator_rss_kb`. Deployed as a
systemd service; `deploy.sh` handles stop/copy/start to avoid "text file busy".

**`rpcstat.sh`** — captures traffic on the RPC port for N seconds, then breaks it
down per source IP: packet counts and JSON-RPC method histogram. Useful for
telling real load apart from idle keep-alive connection pools — connection count
alone is misleading.

**`config/`** — validator launch script and Geyser plugin configuration.

## Setup

Copy `relay01/scripts/nodewatch.conf.example` to `nodewatch.conf` and fill in the
Telegram bot token, chat id and node RPC URL. The real config is gitignored.

```bash
cp nodewatch.conf.example nodewatch.conf
$EDITOR nodewatch.conf
```

Build the Rust components with `cargo build --release`.

## Notes

Snapshot generation is directed to a separate block device via `--snapshots` to
keep archive packaging off the ledger disk. Transaction history is disabled on
this node — it accounted for the large majority of RocksDB write volume without
serving the streaming use case.
