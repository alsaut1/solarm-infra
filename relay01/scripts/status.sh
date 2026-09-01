#!/bin/bash
CSV="/home/alsaut/scripts/metrics.csv"
tail -1 "$CSV" | awk -F, '{
    printf "время:        %s\n", $1
    printf "gRPC:         %s\n", $2
    printf "RPC:          %s\n", $13
    printf "pubsub:       %s (очередь %.1f MB)\n", $14, $15/1048576
    printf "память:       %.1f GB\n", $3/1048576
    printf "CPU geyser:   %s%%\n", $4
    printf "replay:       %d ms из 400\n", $16/1000
    printf "отставание:   %d слотов\n", $7-$5
    printf "финализация:  %d слотов\n", $5-$6
    printf "задержка:     %d слотов\n", $5-$8
    printf "очередь:      %s\n", $9
    printf "трафик:       %.1f MB\n", $12/1048576
}'
