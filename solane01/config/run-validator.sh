#!/bin/bash

exec agave-validator \
  --identity /home/sol/validator-keypair.json \
  --no-voting \
  --full-rpc-api \
  --rpc-port 8899 \
  --rpc-bind-address 0.0.0.0 \
  --dynamic-port-range 8000-8026 \
  --entrypoint entrypoint.mainnet-beta.solana.com:8001 \
  --entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
  --entrypoint entrypoint3.mainnet-beta.solana.com:8001 \
  --entrypoint entrypoint4.mainnet-beta.solana.com:8001 \
  --entrypoint entrypoint5.mainnet-beta.solana.com:8001 \
  --known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
  --known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
  --known-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ \
  --known-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S \
  --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \
  --ledger /mnt/ledger \
  --accounts /mnt/accounts \
  --log /home/sol/logs/agave-validator.log \
  --limit-ledger-size 50000000 \
  --snapshots /mnt/snap \
  --snapshot-interval-slots 5000 \
  --geyser-plugin-config /home/sol/geyser-config.json
