#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Exit script as soon as a command fails.
set -o errexit

# Executes cleanup function at script exit.
trap cleanup EXIT

cleanup() {
    # Kill the nearnode instance that we started (if we started one and if it's still running).
    if [ -n "$node_started" ]; then
        docker kill nearcore watchtower > /dev/null &
    fi
}

nearnode_port=24567

nearnode_running() {
    nc -z localhost "$nearnode_port"
}

start_nearnode() {
    echo "ethrelay" | "$DIR/start_localnet.py" --home "$DIR/.near" --image "nearprotocol/nearcore:nofloatsfixedgas"
    sleep 10
}

if nearnode_running; then
    echo "Using existing nearnode instance"
else
    echo "Starting our own nearnode instance"
    rm -rf "$DIR/.near"
    start_nearnode
    node_started=1
fi

NODE_URL="http://localhost:3030"

echo "Creating account for smart contract:"
NODE_ENV=local yarn run near --nodeUrl=$NODE_URL --homeDir "$DIR/.near" create_account ethbridge --masterAccount=ethrelay --initialBalance 100000000 || echo "Skip creating ethbridge accout"
echo "Deploying smart contract:"
NODE_ENV=local yarn run near --nodeUrl=$NODE_URL --homeDir "$DIR/.near" deploy --contractName ethbridge --wasmFile "$DIR/../../ethbridge/res/eth_bridge.wasm" || echo "Skip deploying ethbridge smart contract"

node "$DIR/../index.js"
