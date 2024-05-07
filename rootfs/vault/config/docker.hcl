ui=true
log_level = "info"
log_requests_level = "info"
pid_file="/vault/config/vault.pid"

telemetry {
    prometheus_retention_time = "24h"
    disable_hostname = true
}

enable_response_header_hostname=true
enable_response_header_raft_node_id=true
