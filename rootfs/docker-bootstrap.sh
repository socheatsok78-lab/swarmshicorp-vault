#!/bin/bash

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

# Docker Swarm Auto Join for Hashicorp Vault
function dockerswarm_auto_join() {
    local auto_join_scheme=${DOCKERSWARM_AUTO_JOIN_SCHEME:-"https"}
    local auto_join_port=${DOCKERSWARM_AUTO_JOIN_PORT:-"8200"}

    # Loop to check the tasks of the service
    local current_cluster_ips=""
    while true; do
        sleep 15
        local auto_join_config=""
        local cluster_ips=$(dig +short "tasks.${1}" | sort)
        # Skip if the cluster_ips is empty
        if [[ -z "${cluster_ips}" ]]; then
            current_cluster_ips="" # reset the current_cluster_ips
            continue
        fi
        if [[ "${current_cluster_ips}" != "${cluster_ips}" ]]; then
            if [ ! -f "$VAULT_PID_FILE" ]; then
                entrypoint_log "==> [Docker Swarm Autopilot] bootstrapping the cluster..."
            fi
            # Update the current_cluster_ips
            current_cluster_ips=$cluster_ips
            # Loop to add the tasks to the auto_join_config
            for task in ${cluster_ips}; do
                # # Skip if the task is the current node
                if [[ "${task}" == "$(hostname -i)" ]]; then
                    continue
                fi
                # Add the task to the auto_join_config
                if [[ -n "${auto_join_config}" ]]; then
                    auto_join_config="${auto_join_config}  "
                fi
                auto_join_config="${auto_join_config}retry_join { leader_api_addr = \"${auto_join_scheme}://${task}:${auto_join_port}\" }"
            done
            # Write the configuration to the file
            echo "storage \"raft\" { ${auto_join_config} }" > "$VAULT_STORAGE_CONFIG_FILE"
            # Send a SIGHUP signal to reload the configuration
            if [ -f "$VAULT_PID_FILE" ]; then
                entrypoint_log "==> [Docker Swarm Autopilot] detected a change in the cluster"
                kill -s SIGHUP $(cat $VAULT_PID_FILE)
            fi
        fi
    done
}

# VAULT_DATA_DIR is exposed as a volume for possible persistent storage. The
# VAULT_CONFIG_DIR isn't exposed as a volume but you can compose additional
# config files in there if you use this image as a base, or use
# VAULT_LOCAL_CONFIG below.
VAULT_DATA_DIR=/vault/file
VAULT_CONFIG_DIR=/vault/config

VAULT_PID_FILE=/vault/config/vault.pid
VAULT_STORAGE_CONFIG_FILE=${VAULT_STORAGE_CONFIG_FILE:-"$VAULT_CONFIG_DIR/raft-storage.hcl"}

# Specifies the address (full URL) to advertise to other
# Vault servers in the cluster for client redirection.
if [ -n "$VAULT_API_INTERFACE" ]; then
    export VAULT_API_ADDR=$(get_addr $VAULT_API_INTERFACE ${VAULT_API_ADDR:-"https://0.0.0.0:8200"})
    entrypoint_log "Using $VAULT_API_INTERFACE for VAULT_API_ADDR: $VAULT_API_ADDR"
fi

# Configure the Vault API address for CLI usage
if [[ -n "${VAULT_API_ADDR}" ]]; then
    export VAULT_ADDR=${VAULT_API_ADDR}
elif [[ -n "${VAULT_REDIRECT_ADDR}" ]]; then
    export VAULT_ADDR=${VAULT_REDIRECT_ADDR}
elif [[ -n "${VAULT_ADVERTISE_ADDR}" ]]; then
    export VAULT_ADDR=${VAULT_ADVERTISE_ADDR}
fi

# Docker Swarm Autopilot
if [[ -n "${DOCKERSWARM_AUTOPILOT}" ]]; then
    entrypoint_log "Enable Docker Swarm Autopilot..."

    # Auto-join the Docker Swarm service
    if [[ -n "${DOCKERSWARM_SERVICE_NAME}" ]]; then
        entrypoint_log "==> [Docker Swarm Autopilot] configure auto-join for \"${DOCKERSWARM_SERVICE_NAME}\" stack..."
        dockerswarm_auto_join $DOCKERSWARM_SERVICE_NAME &
    else
        entrypoint_log "==> [Docker Swarm Autopilot] failed to configure Docker Swarm Autopilot: DOCKERSWARM_SERVICE_NAME is not set"
        exit 1
    fi

    # Generate a random node ID which will be persisted in the data directory
    if [ ! -f "${VAULT_DATA_DIR}/node-id" ]; then
        entrypoint_log "==> [Docker Swarm Autopilot] generate a random node ID which will be persisted in the data directory..."
        uuidgen > "${VAULT_DATA_DIR}/node-id"
    fi
    # Set the VAULT_RAFT_NODE_ID to the content of the node-id file
    VAULT_RAFT_NODE_ID=$(cat "${VAULT_DATA_DIR}/node-id")
fi

# Integrated storage (Raft) backend
if [[ -n "${VAULT_RAFT_NODE_ID}" ]]; then
    entrypoint_log "Configure VAULT_RAFT_NODE_ID as \"$VAULT_RAFT_NODE_ID\""
    export VAULT_RAFT_NODE_ID=${VAULT_RAFT_NODE_ID}
fi
export VAULT_RAFT_PATH=${VAULT_RAFT_PATH:-"/vault/file"}
entrypoint_log "Configure VAULT_RAFT_PATH to \"$VAULT_RAFT_PATH\""

# If DOCKERSWARM_AUTOPILOT is not set, generate the storage configuration based on the provided environment variables
if [[ -z "${DOCKERSWARM_AUTOPILOT}" ]]; then
    # Vault Cloud Auto Join
    if [[ -n "${VAULT_CLOUD_AUTO_JOIN}" ]]; then
        VAULT_CLOUD_AUTO_JOIN_SCHEME=${VAULT_CLOUD_AUTO_JOIN_SCHEME:-"https"}
        VAULT_CLOUD_AUTO_JOIN_PORT=${VAULT_CLOUD_AUTO_JOIN_PORT:-"8201"}
        echo "storage \"raft\" { retry_join { auto_join_scheme=\"${VAULT_CLOUD_AUTO_JOIN_SCHEME}\" auto_join_port=${VAULT_CLOUD_AUTO_JOIN_PORT} auto_join=\"${VAULT_CLOUD_AUTO_JOIN}\" } }" > "$VAULT_STORAGE_CONFIG_FILE"
    fi
    # If VAULT_STORAGE_CONFIG_FILE doesn't exist, generate a default "raft" storage configuration
    if [ ! -f "$VAULT_STORAGE_CONFIG_FILE" ]; then
        # Write the listener configuration to the file
        echo "storage \"raft\" {}" > "$VAULT_STORAGE_CONFIG_FILE"
    fi
fi

# Specifies the identifier for the Vault cluster.
# When connecting to Vault Enterprise, this value will be used in the interface.
# This value also used to identify the cluster in the Prometheus metrics.
VAULT_CLUSTER_NAME=${VAULT_CLUSTER_NAME:-"vault"}
entrypoint_log "Configure VAULT_CLUSTER_NAME as \"$VAULT_CLUSTER_NAME\""

# These are a set of custom environment variables that can be used to
# generate a configuration file on the fly.

VAULT_ENABLE_UI=${VAULT_ENABLE_UI:-"true"}
VAULT_LOG_LEVEL=${VAULT_LOG_LEVEL:-"info"}
VAULT_LOG_REQUESTS_LEVEL=${VAULT_LOG_REQUESTS_LEVEL:-"info"}

# Listener configuration
VAULT_LISTENER_TLS_DISABLE=${VAULT_LISTENER_TLS_DISABLE:-"true"}

# Lease configuration
VAULT_DEFAULT_LEASE_TTL=${VAULT_DEFAULT_LEASE_TTL:-"0"}
VAULT_MAX_LEASE_TTL=${VAULT_MAX_LEASE_TTL:-"0"}
VAULT_DEFAULT_MAX_REQUEST_DURATION=${VAULT_DEFAULT_MAX_REQUEST_DURATION:-"0"}

# Raw storage endpoint configuration
VAULT_RAW_STORAGE_ENDPOINT=${VAULT_RAW_STORAGE_ENDPOINT:-"false"}
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
entrypoint_log "Generating configuration file at \"$VAULT_CONFIG_DIR/docker.hcl\""
cat <<EOT > "$VAULT_CONFIG_DIR/docker.hcl"
ui = ${VAULT_ENABLE_UI}
cluster_name = "${VAULT_CLUSTER_NAME}"
log_level = "${VAULT_LOG_LEVEL}"
log_requests_level = "${VAULT_LOG_REQUESTS_LEVEL}"
pid_file = "${VAULT_PID_FILE}"

# Enables the addition of an HTTP header in all of Vault's HTTP responses: X-Vault-Hostname.
enable_response_header_hostname = true
# Enables the addition of an HTTP header in all of Vault's HTTP responses: X-Vault-Raft-Node-ID.
enable_response_header_raft_node_id = true

# Enables the sys/raw endpoint which allows the decryption/encryption of
# raw data into and out of the security barrier.
# This is a highly privileged endpoint.
raw_storage_endpoint = ${VAULT_RAW_STORAGE_ENDPOINT}

# Lease configuration
default_lease_ttl = "${VAULT_DEFAULT_LEASE_TTL}"
default_max_request_duration = "${VAULT_DEFAULT_MAX_REQUEST_DURATION}"
max_lease_ttl = "${VAULT_MAX_LEASE_TTL}"

# Listener configuration
listener "tcp" {
  address = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable = ${VAULT_LISTENER_TLS_DISABLE}
  tls_cert_file = "${VAULT_LISTENER_TLS_CERT_FILE}"
  tls_key_file = "${VAULT_LISTENER_TLS_KEY_FILE}"
  telemetry {
    unauthenticated_metrics_access = true
  }
}

# Prometheus metrics
telemetry {
    prometheus_retention_time = "24h"
    disable_hostname = true
}
EOT

# If DOCKERSWARM_AUTOPILOT is set, wait for the storage configuration file to be created
if [[ -n "${DOCKERSWARM_AUTOPILOT}" ]]; then
    entrypoint_log "==> [Docker Swarm Autopilot] waiting for auto-join config \"$VAULT_STORAGE_CONFIG_FILE\" to be created..."
    while [ ! -f "$VAULT_STORAGE_CONFIG_FILE" ]; do
        sleep 1
    done
fi

# run the original entrypoint
entrypoint_log "==> Starting Vault server..."
exec docker-entrypoint.sh "${@}"
