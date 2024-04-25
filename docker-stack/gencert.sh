#!/bin/bash
INTERNAL_VAULT_CA_NAME=InternalVaultCA
INTERNAL_VAULT_CERT=vault

if [ -f "out/$INTERNAL_VAULT_CA_NAME.key" ]; then
    echo "File \"out/$INTERNAL_VAULT_CA_NAME.crt\" exists"
else
    certstrap init --common-name "$INTERNAL_VAULT_CA_NAME" --passphrase ""
    docker secret ls --filter name=vault_tls_cacert --format '{{.ID}}' | xargs docker secret rm
    docker secret create vault_tls_cacert out/$INTERNAL_VAULT_CA_NAME.crt
fi

if [ ! -f "out/$INTERNAL_VAULT_CERT.key" ]; then
    certstrap request-cert --common-name $INTERNAL_VAULT_CERT --domain $INTERNAL_VAULT_CERT --passphrase ""
    if [ -f "out/$INTERNAL_VAULT_CERT.crt" ]; then
        echo "File \"out/$INTERNAL_VAULT_CERT.crt\" exists"
    else
        certstrap sign $INTERNAL_VAULT_CERT --CA $INTERNAL_VAULT_CA_NAME --passphrase ""
    fi

    docker secret ls --filter name=vault_tls_key --format '{{.ID}}' | xargs docker secret rm
    docker secret create vault_tls_key out/$INTERNAL_VAULT_CERT.key
fi

if [ ! -f "out/${INTERNAL_VAULT_CERT}_fullchain.crt" ]; then
    cat out/$INTERNAL_VAULT_CERT.crt > out/${INTERNAL_VAULT_CERT}_fullchain.crt
    cat out/$INTERNAL_VAULT_CA_NAME.crt >> out/${INTERNAL_VAULT_CERT}_fullchain.crt

    docker secret ls --filter name=vault_tls_cert --format '{{.ID}}' | xargs docker secret rm
    docker secret create vault_tls_cert out/${INTERNAL_VAULT_CERT}_fullchain.crt
fi
