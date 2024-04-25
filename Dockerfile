ARG VAULT_VERSION=latest
FROM alpine:latest AS selfsigned
RUN apk add --no-cache openssl
RUN openssl req -x509 -newkey rsa:4096 -keyout /vault_tls_key_file.pem -out /vault_tls_cert_file.pem -days 365 -nodes -subj '/CN=vault'

FROM hashicorp/vault:${VAULT_VERSION}
COPY --from=selfsigned vault_tls_key_file.pem /certs/
COPY --from=selfsigned vault_tls_cert_file.pem /certs/
ADD rootfs /
ENV VAULT_RAFT_NODE_ID=
ENV VAULT_RAFT_PATH=/vault/file
ENTRYPOINT [ "/docker-entrypoint-shim.sh" ]
CMD ["server"]
