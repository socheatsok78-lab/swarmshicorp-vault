ui=true
pid_file="/vault/config/vault.pid"

listener "tcp" {
    address = "0.0.0.0:8200"
    tls_disable = true
}

storage "raft" {
    path = "/vault/file"
}

telemetry {
    prometheus_retention_time = "24h"
    disable_hostname = true
}
