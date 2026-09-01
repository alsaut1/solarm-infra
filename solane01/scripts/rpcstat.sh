#!/bin/bash
DUR=${1:-30}
PCAP=/tmp/rpc8899.pcap

echo "=== соединения по IP ==="
ss -tn state established '( sport = :8899 )' \
  | awk 'NR>1{split($NF,a,":"); print a[1]}' | sort | uniq -c | sort -rn > /tmp/rpc_ips.txt
cat /tmp/rpc_ips.txt

IPS=$(awk '{print $2}' /tmp/rpc_ips.txt)

echo
echo "=== снимаю трафик ${DUR}с ==="
timeout "$DUR" tcpdump -i any -s0 -w "$PCAP" 'tcp port 8899' 2>/dev/null
echo "пакетов: $(tcpdump -r "$PCAP" 2>/dev/null | wc -l)"

echo
printf "%-18s %8s  %s\n" "IP" "пакетов" "методы"
for ip in $IPS; do
    pkts=$(tcpdump -r "$PCAP" -nn "host $ip" 2>/dev/null | wc -l)
    methods=$(tcpdump -r "$PCAP" -A -nn "host $ip" 2>/dev/null \
        | grep -oE '"method"[[:space:]]*:[[:space:]]*"[a-zA-Z]+"' \
        | grep -oE '"[a-zA-Z]+"$' | tr -d '"' \
        | sort | uniq -c | sort -rn | awk '{printf "%s=%s ", $2, $1}')
    printf "%-18s %8s  %s\n" "$ip" "$pkts" "${methods:-—}"
done
