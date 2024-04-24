variable "VAULT_VERSION" {
    default = "latest"
}

target "default" {
    context = "."
    dockerfile = "Dockerfile"
    args = {
        VAULT_VERSION = "${VAULT_VERSION}"
    }
    tags = [
        "swarmshicorp-vault:${VAULT_VERSION}"
    ]
}
