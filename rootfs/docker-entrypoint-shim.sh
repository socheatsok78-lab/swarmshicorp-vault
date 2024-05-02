#!/bin/bash
set -e

entrypoint_log() {
    if [ -z "${VAULT_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

# Allow setting VAULT_API_ADDR using an interface
# name instead of an IP address. The interface name is specified using
# VAULT_API_INTERFACE environment variables. If
# VAULT_*_ADDR is also set, the resulting URI will combine the protocol and port
# number with the IP of the named interface.
get_addr () {
    local if_name=$1
    local uri_template=$2
    ip addr show dev $if_name | awk -v uri=$uri_template '/\s*inet\s/ { \
      ip=gensub(/(.+)\/.+/, "\\1", "g", $2); \
      print gensub(/^(.+:\/\/).+(:.+)$/, "\\1" ip "\\2", "g", uri); \
      exit}'
}

# Path to a directory of PEM-encoded CA certificate files on the local disk.
# These certificates are used to verify the Vault server's SSL certificate.
export VAULT_CAPATH=/vault/certs

# Integrated storage (Raft) backend
export VAULT_RAFT_NODE_ID=${VAULT_RAFT_NODE_ID}
export VAULT_RAFT_PATH=${VAULT_RAFT_PATH:-"/vault/file"}
if [[ -z "${VAULT_RAFT_NODE_ID}" ]]; then
    export VAULT_RAFT_NODE_ID=$(hostname)
fi
if [[ -n "${VAULT_RAFT_NODE_ID}" ]]; then
    entrypoint_log "Configure VAULT_RAFT_NODE_ID as \"$VAULT_RAFT_NODE_ID\""
fi
if [[ -n "${VAULT_RAFT_PATH}" ]]; then
    entrypoint_log "Configure VAULT_RAFT_PATH to \"$VAULT_RAFT_PATH\""
fi


# Specifies the address (full URL) to advertise to other
# Vault servers in the cluster for client redirection.
if [ -n "$VAULT_API_INTERFACE" ]; then
    export VAULT_API_ADDR=$(get_addr $VAULT_API_INTERFACE ${VAULT_API_ADDR:-"https://0.0.0.0:8200"})
    export VAULT_ADDR=${VAULT_API_ADDR}
    entrypoint_log "Using $VAULT_API_INTERFACE for VAULT_API_ADDR: $VAULT_API_ADDR"
fi

# run the original entrypoint
echo ""
exec docker-entrypoint.sh "${@}"
