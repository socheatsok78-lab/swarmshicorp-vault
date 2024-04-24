#!/bin/bash
INTERNAL_VAULT_CA_NAME=InternalVaultCA
INTERNAL_VAULT_CERT=vault

if [ -f "out/$INTERNAL_VAULT_CA_NAME.key" ]; then
    echo "File \"out/$INTERNAL_VAULT_CA_NAME.crt\" exists"
else
    certstrap init --common-name "$INTERNAL_VAULT_CA_NAME" --passphrase ""
fi

if [ ! -f "out/$INTERNAL_VAULT_CERT.key" ]; then
    certstrap request-cert --common-name $INTERNAL_VAULT_CERT --passphrase ""
    if [ -f "out/$INTERNAL_VAULT_CERT.crt" ]; then
        echo "File \"out/$INTERNAL_VAULT_CERT.crt\" exists"
    else
        certstrap sign $INTERNAL_VAULT_CERT --CA $INTERNAL_VAULT_CA_NAME --passphrase ""
    fi

    docker secret ls --filter name=vault_tls_cert_file --format '{{.ID}}' | xargs docker secret rm
    docker secret create vault_tls_cert_file out/$INTERNAL_VAULT_CERT.crt

    docker secret ls --filter name=vault_tls_key_file --format '{{.ID}}' | xargs docker secret rm
    docker secret create vault_tls_key_file out/$INTERNAL_VAULT_CERT.key
fi
