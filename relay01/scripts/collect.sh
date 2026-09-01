#!/bin/bash

NODE="5.43.224.31"
CSV="/home/alsaut/scripts/metrics.csv"

if [ ! -f "$CSV" ]; then
    echo "ts,conns,rss_kb,cpu_pct,processed,rooted,first_shred,plugin_processed,msg_queue,block_queue,dropped,traffic,rpc_conns,pubsub_conns,pubsub_sendq,replay_us" > "$CSV"
fi

exp=$(curl -s --max-time 5 "http://${NODE}:9101/metrics")
prom=$(curl -s --max-time 5 "http://${NODE}:8999/metrics")

val() {
    echo "$1" | grep -m1 "^$2" | awk '{print $NF}'
}

conns=$(val "$exp" "grpc_connections")
rss=$(val "$exp" "validator_rss_kb")
cpu=$(val "$exp" "cpu_geyser_pct")
rpc_conns=$(val "$exp" "rpc_connections")
pubsub_conns=$(val "$exp" "pubsub_connections")
pubsub_sendq=$(val "$exp" "pubsub_sendq_bytes")
replay_us=$(val "$exp" "replay_elapsed_us")
processed=$(echo "$prom" | grep -m1 'slot_status{status="processed"}' | awk '{print $NF}')
rooted=$(echo "$prom" | grep -m1 'slot_status{status="rooted"}' | awk '{print $NF}')
first=$(echo "$prom" | grep -m1 'slot_status{status="first_shred_received"}' | awk '{print $NF}')
plugin=$(echo "$prom" | grep -m1 'slot_status_plugin{status="processed"}' | awk '{print $NF}')
msgq=$(val "$prom" "yellowstone_grpc_geyser_message_queue_size")
blockq=$(val "$prom" "yellowstone_grpc_geyser_block_reconstruction_queue_size")
dropped=$(val "$prom" "yellowstone_grpc_geyser_untrack_slot_event_dropped_total")
traffic=$(echo "$prom" | grep '^yellowstone_grpc_geyser_total_traffic_sent_bytes' | awk '{s+=$NF} END {print s+0}')

echo "$(date '+%F %T'),${conns:-},${rss:-},${cpu:-},${processed:-},${rooted:-},${first:-},${plugin:-},${msgq:-},${blockq:-},${dropped:-},${traffic:-},${rpc_conns:-},${pubsub_conns:-},${pubsub_sendq:-},${replay_us:-}" >> "$CSV"
