#!/bin/sh
set -e

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

if [ -n "$VAULT_API_INTERFACE" ]; then
    export VAULT_API_ADDR=$(get_addr $VAULT_API_INTERFACE ${VAULT_API_ADDR:-"https://0.0.0.0:8200"})
    export VAULT_ADDR=${VAULT_API_ADDR}
    echo "Using $VAULT_API_INTERFACE for VAULT_API_ADDR: $VAULT_API_ADDR"
fi

# Integrated storage (Raft) backend
if [[ -z "${VAULT_RAFT_NODE_ID}" ]]; then
    export VAULT_RAFT_NODE_ID=$(hostname)
    echo "Using VAULT_RAFT_NODE_ID: $VAULT_RAFT_NODE_ID"
fi

# run the original entrypoint
exec docker-entrypoint.sh "${@}"
