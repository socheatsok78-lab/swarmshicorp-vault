# Terraform cluster configuration for HashiCorp Vault

This is a generic cluster configuration for HashiCorp Vault running inside a Docker Swarm environment.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html)

## Usage

1. Deploy Vault to Docker Swarm
2. Initialize Vault
3. Unseal Vault
4. Enable authentication methods (optional, you can use `root` token)
5. Apply terraform configuration

### Apply the terraform configuration

```bash
terraform init # Only required once
terraform apply
```
