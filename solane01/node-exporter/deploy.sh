#!/bin/bash
set -e
cd ~/projects/node-exporter
cargo build --release
sudo systemctl stop node-exporter
sudo cp target/release/node-exporter /opt/node-exporter/node-exporter
sudo systemctl start node-exporter
sleep 1
curl -s localhost:9101/metrics
