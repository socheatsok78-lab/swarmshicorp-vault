ARG VAULT_VERSION=latest
FROM hashicorp/vault:${VAULT_VERSION}
RUN apk add --no-cache bash ca-certificates
ADD rootfs /
ENTRYPOINT [ "/docker-entrypoint-shim.sh" ]
CMD ["server"]

# Path to a directory of PEM-encoded CA certificate files on the local disk.
# These certificates are used to verify the Vault server's SSL certificate.
ENV VAULT_CAPATH=/vault/certs

# Integrated storage (Raft) backend
ENV VAULT_RAFT_NODE_ID=
ENV VAULT_RAFT_PATH=/vault/file

# Specifies the address (full URL) to advertise to other
# Vault servers in the cluster for client redirection.
ENV VAULT_API_INTERFACE=eth0
ENV VAULT_API_ADDR=https://0.0.0.0:8200

# # Specifies the address (full URL) that should be used for other
# cluster members to connect to this node when in High Availability mode.
ENV VAULT_CLUSTER_INTERFACE=eth0
ENV VAULT_CLUSTER_ADDR=https://0.0.0.0:8201

# Specifies the address (full URL) that should be used when 
# clients are redirected to this node when in High Availability mode.
ENV VAULT_REDIRECT_INTERFACE=eth0
ENV VAULT_REDIRECT_ADDR=
