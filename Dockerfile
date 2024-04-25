ARG VAULT_VERSION=latest
FROM hashicorp/vault:${VAULT_VERSION}
RUN apk add --no-cache bash
ADD rootfs /
ENV VAULT_RAFT_NODE_ID=
ENV VAULT_RAFT_PATH=/vault/file
ENTRYPOINT [ "/docker-entrypoint-shim.sh" ]
CMD ["server"]
