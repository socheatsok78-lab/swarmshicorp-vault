ARG VAULT_VERSION=latest
FROM hashicorp/vault:${VAULT_VERSION}
RUN apk add --no-cache bash ca-certificates
ADD rootfs /
RUN chmod +x /docker-bootstrap.sh 
RUN chown -R vault:vault /vault/config
VOLUME [ "/vault/certs" ]
ENTRYPOINT [ "/docker-bootstrap.sh" ]
CMD ["server"]
