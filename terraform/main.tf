#------------------------------------------------------------------------------
# The best practice is to use remote state file and encrypt it since your
# state files may contains sensitive data (secrets).
#------------------------------------------------------------------------------
# terraform {
#       backend "s3" {
#             bucket = "remote-terraform-state-dev"
#             encrypt = true
#             key = "terraform.tfstate"
#             region = "us-east-1"
#       }
# }

# Use Vault provider
provider "vault" {
  # It is strongly recommended to configure this provider through the
  # environment variables:
  #    - VAULT_ADDR
  #    - VAULT_TOKEN
  #    - VAULT_CACERT
  #    - VAULT_CAPATH
  #    - etc.  
}

# ==============================================================================
# Vault Cluster Configuration
# ==============================================================================

# Enable Audit devices to log all requests to stdout
# See https://developer.hashicorp.com/vault/docs/audit
resource "vault_audit" "stdout" {
  type = "file"
  options = {
    file_path = "stdout"
  }
}

# Raft Autopilot Configuration
# See https://developer.hashicorp.com/vault/docs/concepts/integrated-storage/autopilot
resource "vault_raft_autopilot" "autopilot" {
  cleanup_dead_servers = true
  dead_server_last_contact_threshold = "24h0m0s"
  last_contact_threshold = "10s"
  max_trailing_logs = 1000
  min_quorum = 3
  server_stabilization_time = "10s"
}
