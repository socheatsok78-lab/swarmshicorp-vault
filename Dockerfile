ARG VAULT_VERSION=latest
FROM hashicorp/vault:${VAULT_VERSION}
RUN apk add --no-cache bash ca-certificates
ADD rootfs /
VOLUME [ "/vault/certs" ]
ENTRYPOINT [ "/docker-entrypoint-shim.sh" ]
CMD ["server"]
