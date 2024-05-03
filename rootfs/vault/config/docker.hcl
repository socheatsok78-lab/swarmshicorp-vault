ui=true
enable_response_header_hostname=true
enable_response_header_raft_node_id=true
log_level = "info"
log_requests_level = "info"
pid_file="/vault/config/vault.pid"

listener "tcp" {
    address = "0.0.0.0:8200"
    tls_disable = true
}

storage "raft" {}

telemetry {
    prometheus_retention_time = "24h"
    disable_hostname = true
}
