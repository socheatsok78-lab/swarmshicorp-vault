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

# VAULT_CONFIG_DIR isn't exposed as a volume but you can compose additional
# config files in there if you use this image as a base, or use
# VAULT_LOCAL_CONFIG below.
VAULT_CONFIG_DIR=/vault/config

# Path to a directory of PEM-encoded CA certificate files on the local disk.
# These certificates are used to verify the Vault server's SSL certificate.
export VAULT_CAPATH=/vault/certs

# Specifies the identifier for the Vault cluster.
# When connecting to Vault Enterprise, this value will be used in the interface.
# This value also used to identify the cluster in the Prometheus metrics.
export VAULT_CLUSTER_NAME=${VAULT_CLUSTER_NAME:-"vault"}
entrypoint_log "Configure VAULT_CLUSTER_NAME as \"$VAULT_CLUSTER_NAME\""

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

# If VAULT_LISTENER_CONFIG_FILE doesn't exist, generate a default "tcp" listener configuration
export VAULT_LISTENER_CONFIG_FILE=${VAULT_LISTENER_CONFIG_FILE:-"$VAULT_CONFIG_DIR/listener.hcl"}
if [ ! -f "$VAULT_LISTENER_CONFIG_FILE" ]; then
    # If VAULT_LISTENER_TLS_KEY_FILE and VAULT_LISTENER_TLS_CERT_FILE are set, enable TLS
    VAULT_LISTENER_TLS_CONFIG="  tls_disable = true"
    if [ -n "$VAULT_LISTENER_TLS_KEY_FILE" ] && [ -n "$VAULT_LISTENER_TLS_CERT_FILE" ]; then
        VAULT_LISTENER_TLS_CONFIG="  tls_key_file = \"$VAULT_LISTENER_TLS_KEY_FILE\"\n  tls_cert_file = \"$VAULT_LISTENER_TLS_CERT_FILE\""
    elif [ -n "$VAULT_LISTENER_TLS_KEY_FILE" ] || [ -n "$VAULT_LISTENER_TLS_CERT_FILE" ]; then
        echo "The VAULT_LISTENER_TLS_KEY_FILE and VAULT_LISTENER_TLS_CERT_FILE environment variables must be set to enable TLS."
    fi

    # Write the listener configuration to the file
    echo -e "listener \"tcp\" {\n  address = \"0.0.0.0:8200\"\n${VAULT_LISTENER_TLS_CONFIG}\n}" > "$VAULT_LISTENER_CONFIG_FILE"
fi

# If VAULT_STORAGE_CONFIG_FILE doesn't exist, generate a default "raft" storage configuration
export VAULT_STORAGE_CONFIG_FILE=${VAULT_STORAGE_CONFIG_FILE:-"$VAULT_CONFIG_DIR/raft-storage.hcl"}
if [ ! -f "$VAULT_STORAGE_CONFIG_FILE" ]; then
    # Write the listener configuration to the file
    echo "storage \"raft\" {}" > "$VAULT_STORAGE_CONFIG_FILE"
fi

# These are a set of custom environment variables that can be used to
# generate a configuration file on the fly.

# Lease configuration
export VAULT_DEFAULT_LEASE_TTL=${VAULT_DEFAULT_LEASE_TTL:-"0"}
export VAULT_MAX_LEASE_TTL=${VAULT_MAX_LEASE_TTL:-"0"}
export VAULT_DEFAULT_MAX_REQUEST_DURATION=${VAULT_DEFAULT_MAX_REQUEST_DURATION:-"0"}

# Raw storage endpoint configuration
export VAULT_RAW_STORAGE_ENDPOINT=${VAULT_RAW_STORAGE_ENDPOINT:-"false"}
if [[ "${VAULT_RAW_STORAGE_ENDPOINT}" == "true" ]]; then
    entrypoint_log ""
    entrypoint_log "----------------------------------------------------------------------"
    entrypoint_log "                            !!! WARNING !!!                           "
    entrypoint_log "----------------------------------------------------------------------"
    entrypoint_log "Vault is configured to use the raw storage endpoint. This is a highly"
    entrypoint_log "privileged endpoint"
    entrypoint_log ""
    entrypoint_log "Enables the sys/raw endpoint which allows the decryption/encryption"
    entrypoint_log "of raw data into and out of the security barrier."
    entrypoint_log "----------------------------------------------------------------------"
fi

# Save the configuration to a file
cat <<EOT > "$VAULT_CONFIG_DIR/cluster.hcl"
cluster_name = "$VAULT_CLUSTER_NAME"

# Enables the sys/raw endpoint which allows the decryption/encryption of
# raw data into and out of the security barrier.
# This is a highly privileged endpoint.
raw_storage_endpoint = ${VAULT_RAW_STORAGE_ENDPOINT}

# Lease configuration
default_lease_ttl = "${VAULT_DEFAULT_LEASE_TTL}"
default_max_request_duration = "${VAULT_DEFAULT_MAX_REQUEST_DURATION}"
max_lease_ttl = "${VAULT_MAX_LEASE_TTL}"
EOT

# run the original entrypoint
entrypoint_log ""
exec docker-entrypoint.sh "${@}"
