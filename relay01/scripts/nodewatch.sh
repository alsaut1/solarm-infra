#!/bin/bash
source /home/alsaut/scripts/nodewatch.conf

NODE_IP="5.43.224.31"
RSS_LIMIT_KB=440401920   # 420 ГБ из 503

notify() {
    curl -s -o /dev/null \
        "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d chat_id="${TG_CHAT}" \
        -d text="$1"
}

rpc() {
    local params=""
    [ -n "$2" ] && params=",\"params\":[{\"commitment\":\"$2\"}]"
    curl -s --max-time 10 "$NODE_URL" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$1\"${params}}" \
        | jq -r '.result'
}

rpc_public() {
    curl -s --max-time 10 https://api.mainnet-beta.solana.com \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' \
        | jq -r '.result'
}

health=$(rpc getHealth)
slot1=$(rpc getSlot)
sleep 15
slot2=$(rpc getSlot)
net_slot=$(rpc_public)
proc_slot=$(rpc getSlot processed)
rss_kb=$(curl -s --max-time 5 "http://${NODE_IP}:9101/metrics" | grep -m1 "^validator_rss_kb" | awk '{print $NF}')

if [ "$health" != "ok" ]; then
    status="fail"
    msg="🔴 solane01: getHealth = $health"
elif [ "$slot2" -le "$slot1" ]; then
    status="fail"
    msg="🔴 solane01: слот не растёт ($slot1 → $slot2), реплей завис"
elif [ -n "$rss_kb" ] && [ "$rss_kb" -gt "$RSS_LIMIT_KB" ]; then
    status="fail"
    msg="🔴 solane01: память $((rss_kb/1024/1024)) ГБ из 503, риск OOM"
elif [ "$proc_slot" -gt 0 ] && [ "$((proc_slot - slot2))" -gt 150 ]; then
    status="fail"
    msg="🔴 solane01: финализация отстаёт на $((proc_slot - slot2)) слотов (processed=$proc_slot finalized=$slot2), риск OOM"
elif [ "$net_slot" -gt 0 ] && [ "$((net_slot - slot2))" -gt 300 ]; then
    status="fail"
    msg="🟠 solane01: отставание от сети $((net_slot - slot2)) слотов (наш $slot2, сеть $net_slot)"
else
    status="ok"
    msg="🟢 solane01: восстановилась (delta=$((slot2 - slot1)) gap=$((net_slot - slot2)) fin=$((proc_slot - slot2)) rss=$((rss_kb/1024/1024))ГБ)"
fi

STATE_FILE="/home/alsaut/scripts/nodewatch.state"
prev=$(cat "$STATE_FILE" 2>/dev/null)

if [ "$status" != "$prev" ]; then
    notify "$msg"
    echo "$(date '+%F %T') статус изменился: ${prev:-нет данных} → $status"
else
    echo "$(date '+%F %T') без изменений: $status"
fi

echo "$status" > "$STATE_FILE"
