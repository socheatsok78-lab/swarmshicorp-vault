ARG VAULT_VERSION=latest
FROM hashicorp/vault:${VAULT_VERSION}
RUN apk add --no-cache bash bind-tools ca-certificates uuidgen
ADD rootfs /
RUN chmod +x /docker*.sh
VOLUME [ "/vault/certs" ]
ENTRYPOINT [ "/docker-entrypoint-shim.sh" ]
CMD ["server"]
