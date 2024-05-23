#!/bin/bash

entrypoint_log() {
    if [ -z "${VAULT_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

# Get IP address using the Docker service network name instead of interface name
function dockerswarm_network_addr() {
    local network_name=$1
    if [ -z "$network_name" ]; then
        echo "[dockerswarm_network_addr]: command line is not complete, network name is required"
        return 1
    fi
    # Loop through assigned IP addresses to the host
    for ip in $(hostname -i); do
        # Query the PTR record for the IP address
        local ptr_record=$(host "$ip" | cut -d ' ' -f 5)
        # If the PTR record is empty, skip to the next IP address
        if [ -z "$ptr_record" ]; then
            continue
        fi
        # Filter the PTR record to get the network name
        local service_network=$(echo "$ptr_record" | cut -d '.' -f 4)
        # Check if the network name matches the input network name
        if [[ "$service_network" == *"$network_name" ]]; then
            echo "$ip"
            return
        fi
    done

    echo "[dockerswarm_network_addr]: can't find network '$network_name'"
    return 2
}

function dockerswarm_get_addr() {
    local if_name=$1
    local uri_template=$2
    dockerswarm_network_addr $if_name | awk -v uri=$uri_template '{print gensub(/^(.+:\/\/).+(:.+)$/, "\\1" $1 "\\2", "g", uri)}'
}

# Docker Swarm Auto Join for Hashicorp Vault
function dockerswarm_auto_join() {
    local auto_join_scheme=${DOCKERSWARM_AUTO_JOIN_SCHEME:-"http"}
    local auto_join_port=${DOCKERSWARM_AUTO_JOIN_PORT:-"8200"}

    # Loop to check the tasks of the service
    local current_cluster_ips=""
    while true; do
        local auto_join_config=""
        local cluster_ips=$(dig +short "tasks.${1}" | sort)
        # Skip if the cluster_ips is empty
        if [[ -z "${cluster_ips}" ]]; then
            current_cluster_ips="" # reset the current_cluster_ips
            continue
        fi
        if [[ "${current_cluster_ips}" != "${cluster_ips}" ]]; then
            if [ ! -f "$VAULT_PID_FILE" ]; then
                entrypoint_log "==> [Docker Swarm Entrypoint] bootstrapping the cluster..."
            fi
            # Update the current_cluster_ips
            current_cluster_ips=$cluster_ips
            # Loop to add the tasks to the auto_join_config
            for task in ${cluster_ips}; do
                # Skip if the task is the current node
                if [[ "$(hostname -i)" == *"${task}"* ]]; then
                    continue
                fi
                # Add the task to the auto_join_config
                if [[ -n "${auto_join_config}" ]]; then
                    auto_join_config="${auto_join_config} "
                fi
                auto_join_config="${auto_join_config}retry_join { leader_api_addr = \"${auto_join_scheme}://${task}:${auto_join_port}\" }"
            done
            # Write the configuration to the file
            echo "storage \"raft\" { ${auto_join_config} }" > "$VAULT_STORAGE_CONFIG_FILE"
            # Send a SIGHUP signal to reload the configuration
            if [ -f "$VAULT_PID_FILE" ]; then
                entrypoint_log "==> [Docker Swarm Entrypoint] detected a change in the cluster"
                kill -s SIGHUP $(cat $VAULT_PID_FILE)
            fi
        fi
        sleep 15
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

# Docker Swarm Entrypoint
echo "Enable Docker Swarm Entrypoint..."
export DOCKERSWARM_ENTRYPOINT=true

# !!! IMPORTANT !!!
DOCKERSWARM_STARTUP_DELAY=${DOCKERSWARM_STARTUP_DELAY:-15}
echo "==> [Docker Swarm Entrypoint] Waiting for Docker to configure the network and DNS resolution... (${DOCKERSWARM_STARTUP_DELAY}s)"
sleep ${DOCKERSWARM_STARTUP_DELAY}

# Auto-join the Docker Swarm service
if [[ -n "${DOCKERSWARM_SERVICE_NAME}" ]]; then
    echo "==> [Docker Swarm Entrypoint] configure auto-join for \"${DOCKERSWARM_SERVICE_NAME}\" stack..."
    dockerswarm_auto_join $DOCKERSWARM_SERVICE_NAME &
else
    echo "==> [Docker Swarm Entrypoint] failed to configure auto-join: DOCKERSWARM_SERVICE_NAME is not set"
    exit 1
fi

# Generate a random node ID which will be persisted in the data directory
if [ ! -f "${VAULT_DATA_DIR}/node-id" ]; then
    echo "==> [Docker Swarm Entrypoint] generate a random node ID which will be persisted in the data directory..."
    uuidgen > "${VAULT_DATA_DIR}/node-id"
fi
# Set the VAULT_RAFT_NODE_ID to the content of the node-id file
export VAULT_RAFT_NODE_ID=$(cat "${VAULT_DATA_DIR}/node-id")

# Set the VAULT_*_ADDR using VAULT_*_NETWORK
if [ -n "$VAULT_API_NETWORK" ]; then
    export VAULT_API_ADDR=$(dockerswarm_get_addr $VAULT_API_NETWORK ${VAULT_API_ADDR:-"https://0.0.0.0:8200"})
    echo "==> [Docker Swarm Entrypoint] Using \"$VAULT_API_NETWORK\" network for VAULT_API_ADDR: $VAULT_API_ADDR"
fi
if [ -n "$VAULT_REDIRECT_NETWORK" ]; then
    export VAULT_REDIRECT_ADDR=$(dockerswarm_get_addr $VAULT_REDIRECT_NETWORK ${VAULT_REDIRECT_ADDR:-"http://0.0.0.0:8200"})
    echo "==> [Docker Swarm Entrypoint] Using \"$VAULT_REDIRECT_NETWORK\" network for VAULT_REDIRECT_ADDR: $VAULT_REDIRECT_ADDR"
fi
if [ -n "$VAULT_CLUSTER_NETWORK" ]; then
    export VAULT_CLUSTER_ADDR=$(dockerswarm_get_addr $VAULT_CLUSTER_NETWORK ${VAULT_CLUSTER_ADDR:-"https://0.0.0.0:8201"})
    echo "==> [Docker Swarm Entrypoint] Using \"$VAULT_CLUSTER_NETWORK\" network for VAULT_CLUSTER_ADDR: $VAULT_CLUSTER_ADDR"
fi

# If DOCKERSWARM_ENTRYPOINT is set, wait for the storage configuration file to be created
if [[ -n "${DOCKERSWARM_ENTRYPOINT}" ]]; then
    entrypoint_log "==> [Docker Swarm Autopilot] waiting for auto-join config \"$VAULT_STORAGE_CONFIG_FILE\" to be created..."
    while [ ! -f "$VAULT_STORAGE_CONFIG_FILE" ]; do
        sleep 1
    done
fi

exec /docker-entrypoint-shim.sh "${@}"
