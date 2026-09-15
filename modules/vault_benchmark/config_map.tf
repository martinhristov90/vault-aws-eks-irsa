resource "kubernetes_config_map_v1" "vault-benchmark-config" {
  metadata {
    name      = "vault-benchmark-configmap"
    namespace = var.namespace
  }
  # vault_token is intentionally absent — it is read at runtime from the
  # vault-root-creds secret mounted at /vault-root-creds/root_token and
  # injected via VAULT_TOKEN so the ConfigMap never holds a stale value.
  data = {
    "k8s.hcl" = <<EOF
        # Basic Benchmark config options
        vault_addr = "https://${local.vault_service_name}.${var.namespace}:8200"
        ca_pem_file = "/vault-ca/ca.crt"
        duration = "24h"
        report_mode = "terse"
        random_mounts = true
        cleanup = true
        test "kvv2_write" "static_secret_writes" {
          weight = 50
          config {
            numkvs = 100
            kvsize = 100
          }
        }
        test "approle_auth" "approle_logins" {
          weight = 50
          config {
            role {
              role_name = "benchmark-role"
              token_ttl="168h"
            }
          }
        }
    EOF
  }
}