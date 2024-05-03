#!/bin/bash

entrypoint_log() {
    if [ -z "${VAULT_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

VAULT_PID_FILE="/vault/config/vault.pid"

# Integrated storage (Raft) backend
VAULT_RAFT_AUTO_JOIN_SCHEME="http"
VAULT_RAFT_AUTO_JOIN_HOST="server"
VAULT_RAFT_AUTH_JOIN_PORT="8200"

VAULT_CURRENT_ADDRESS_POOL=""
VAULT_NEW_ADDRESS_POOL=""
VAULT_RAFT_STORAGE_CONFIG=""
VAULT_RAFT_STORAGE_CONFIG_FILE="/vault/config/raft-storage.hcl"


function vault_raft_autojoin() {
    NEW_ADDRESS_POOL=""
    VAULT_RAFT_STORAGE_CONFIG+="storage "raft" {\n"
    while read -r VAULT_RAFT_NODE_IP; do
        VAULT_RAFT_STORAGE_CONFIG+="    retry_join {\n"
        VAULT_RAFT_STORAGE_CONFIG+="        leader_api_addr = \"${VAULT_RAFT_AUTO_JOIN_SCHEME}://${VAULT_RAFT_NODE_IP}:${VAULT_RAFT_AUTH_JOIN_PORT}\"\n"
        VAULT_RAFT_STORAGE_CONFIG+="    }\n"
        NEW_ADDRESS_POOL="${VAULT_RAFT_NODE_IP}::${NEW_ADDRESS_POOL}"
    done < <(dig @127.0.0.11 +short "tasks.${VAULT_RAFT_AUTO_JOIN_HOST}")
    VAULT_RAFT_STORAGE_CONFIG+="}"
    echo "$VAULT_RAFT_STORAGE_CONFIG" > "$VAULT_RAFT_STORAGE_CONFIG_FILE"
    VAULT_RAFT_STORAGE_CONFIG=""
}
function main() {
    echo "Initializing Vault Raft Storage..."
    vault_raft_autojoin
    CURRENT_ADDRESS_POOL="${NEW_ADDRESS_POOL}"

    while true; do
        echo "Checking for new nodes to join..."
        vault_raft_autojoin
        if [[ "${NEW_ADDRESS_POOL}" != "${CURRENT_ADDRESS_POOL}" ]]; then
            echo "New nodes found, sending HUP signal to Vault..."
            kill -s HUP $(cat "$VAULT_PID_FILE")
            CURRENT_ADDRESS_POOL="${NEW_ADDRESS_POOL}"
        fi
        echo "CURRENT_ADDRESS_POOL=${CURRENT_ADDRESS_POOL}"
        echo "NEW_ADDRESS_POOL=${NEW_ADDRESS_POOL}"
        sleep 15
    done
}
main
