variable "VAULT_VERSION" {
    default = "latest"
}

target "docker-metadata-action" {}
target "github-metadata-action" {}

target "default" {
    inherits = [
        "swarmshicorp-vault",
    ]
    platforms = [
        "linux/amd64",
        "linux/arm64"
    ]
}

target "makefile" {
    inherits = [
        "swarmshicorp-vault",
    ]
    tags = [
        "swarmshicorp-vault:local"
    ]
}

target "swarmshicorp-vault" {
    context = "."
    dockerfile = "Dockerfile"
    inherits = [
        "docker-metadata-action",
        "github-metadata-action",
    ]
    args = {
        VAULT_VERSION = "${VAULT_VERSION}"
    }
}
