ARG VAULT_VERSION=latest
FROM hashicorp/vault:${VAULT_VERSION}
RUN apk add --no-cache bash bind-tools ca-certificates uuidgen
ADD rootfs /
RUN chmod +x /docker-bootstrap.sh 
RUN chown -R vault:vault /vault/config
VOLUME [ "/vault/certs" ]
ENTRYPOINT [ "/docker-bootstrap.sh" ]
CMD ["server"]
