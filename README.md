## About

A wrapper for HashiCorp Vault to aid deployment inside Docker Swarm.

## Environment Variables

You can configure the Vault server by setting the following environment variables.

### Listener Configuration

- `VAULT_LISTENER_CONFIG_FILE`: The path to the listener configuration file. (Default: `/vault/config/listener.hcl`)

    > If the file specified by `VAULT_LISTENER_CONFIG_FILE` does not exist, the `docker-bootstrap.sh` script will attempt to create a default listener configuration file at the specified path.
    >
    > This allow you to specify your own listener configuration file by mounting it to the container at the specified path. Either by using a **Docker volume** or a **Docker Config**.

- `VAULT_API_INTERFACE`: The interface to bind the `VAULT_API_ADDR` to. (Optional)
- `VAULT_API_ADDR`: The address to bind the Vault API to. (Optional)

**Enable TLS for the listener**

To enable TLS for the listener, you can specify the following environment variables:
- `VAULT_LISTENER_TLS_KEY_FILE`: The path to the TLS key file. (Optional)
- `VAULT_LISTENER_TLS_CERT_FILE`: The path to the TLS certificate file. (Optional)

    > If the `VAULT_LISTENER_TLS_KEY_FILE` and `VAULT_LISTENER_TLS_CERT_FILE` environment variables are set, the `docker-bootstrap.sh` script will attempt to create a default listener configuration file with TLS enabled at the specified path. Otherwise, the default listener configuration file will be created with TLS disabled.

### Storage Configuration

- `VAULT_RAFT_NODE_ID`: The Raft node ID of the Vault node. (Default: `$(hostname)`)
- `VAULT_RAFT_PATH`: The path to the Raft storage directory. (Default: `/vault/file`)
- `VAULT_STORAGE_CONFIG_FILE`: The path to the storage configuration file. (Default: `/vault/config/raft-storage.hcl`)

    > If the file specified by `VAULT_STORAGE_CONFIG_FILE` does not exist, the `docker-bootstrap.sh` script will attempt to create a default storage configuration file at the specified path.

    **Default Storage Configuration**
    ```hcl
    # The "path" to the Raft storage directory is defined by the VAULT_RAFT_PATH environment variable.
    # The same as "node_id" is defined by the VAULT_RAFT_NODE_ID environment variable.

    storage "raft" {}
    ```

### Additional Configuration

The following environment variables can be used to specify additional configuration options for the Vault server.

- `VAULT_CLUSTER_NAME`: The name of the Vault cluster. (Default: `vault`)
- `VAULT_RAW_STORAGE_ENDPOINT`: Enable the sys/raw endpoint which allows the decryption/encryption of raw data into and out of the security barrier. (Default: `false`)
- `VAULT_DEFAULT_LEASE_TTL`: The default lease duration for tokens and secrets. (Default: `0`)
- `VAULT_DEFAULT_MAX_REQUEST_DURATION`: The default maximum request duration. (Default: `0`)
- `VAULT_MAX_LEASE_TTL`: The maximum lease duration for tokens and secrets. (Default: `0`)

**Output Configuration**

```hcl
cluster_name = "${VAULT_CLUSTER_NAME}"

# Enables the sys/raw endpoint which allows the decryption/encryption of
# raw data into and out of the security barrier.
# This is a highly privileged endpoint.
raw_storage_endpoint = ${VAULT_RAW_STORAGE_ENDPOINT}

# Lease configuration
default_lease_ttl = "${VAULT_DEFAULT_LEASE_TTL}"
default_max_request_duration = "${VAULT_DEFAULT_MAX_REQUEST_DURATION}"
max_lease_ttl = "${VAULT_MAX_LEASE_TTL}"
```
