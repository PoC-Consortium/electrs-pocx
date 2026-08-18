#!/bin/bash
# Start Bitcoin-PoCX Core in the background
echo "Starting Bitcoin-PoCX Core (bitcoind)..."
bitcoind -datadir=/root/.bitcoin-pocx "$@" &
BITCOIND_PID=$!

# Function to handle graceful shutdown
shutdown_handler() {
    echo "Shutdown signal received. Stopping services..."
    # Tell bitcoind to stop gracefully
    bitcoin-cli -datadir=/root/.bitcoin-pocx stop
    # Wait for bitcoind to actually exit
    wait $BITCOIND_PID
    echo "Services stopped. Exiting."
    exit 0
}

# Trap SIGTERM and SIGINT
trap 'shutdown_handler' SIGTERM SIGINT

# Wait for the cookie file or RPC port to become active before starting electrs
echo "Waiting for bitcoind to initialize..."
until [ -f /root/.bitcoin-pocx/.cookie ]; do
    sleep 2
done

DAEMON_DIR="/root/.bitcoin-pocx"

echo "Bitcoin-PoCX Core is ready. Starting BTCX Electrum Server (electrs)..."
# Start electrs in the background so we can manage the shell signals
electrs \
    --network bitcoin \
    --daemon-dir "$DAEMON_DIR" \
    --db-dir /db \
    --electrum-rpc-addr 0.0.0.0:50001 \
    --log-filters INFO &
ELECTRS_PID=$!

# Wait for processes to exit (or for a trap to trigger)
wait $ELECTRS_PID
shutdown_handler
