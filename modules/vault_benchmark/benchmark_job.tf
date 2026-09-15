# Vault benchmark job
resource "kubernetes_job_v1" "demo" {
  metadata {
    name      = "vault-benchmark"
    namespace = var.namespace
  }
  spec {
    template {
      metadata {}
      spec {
        # Wait until Vault is unsealed and active before starting the benchmark.
        # Polls /v1/sys/health with perfstandbyok=true so both active and standby
        # nodes return 200. Uses the internal CA cert for proper TLS verification.
        init_container {
          name    = "wait-for-vault"
          image   = "curlimages/curl:8.7.1"
          command = ["/bin/sh", "-c"]
          args    = ["until curl -sf --cacert /vault-ca/ca.crt 'https://${local.vault_service_name}.${var.namespace}:8200/v1/sys/health?perfstandbyok=true&standbyok=true' > /dev/null 2>&1; do echo 'waiting for Vault to become active...'; sleep 5; done; echo 'Vault is ready'"]
          volume_mount {
            mount_path = "/vault-ca"
            name       = "vault-ca"
            read_only  = true
          }
        }
        container {
          name  = "vault-benchmark"
          image = "hashicorp/vault-benchmark:latest"
          # Read the root token from the mounted secret at runtime, trim the
          # trailing newline, export it as VAULT_TOKEN, then run the benchmark.
          command = ["/bin/sh", "-c"]
          args    = ["export VAULT_TOKEN=$(cat /vault-root-creds/root_token | tr -d '\\n') && vault-benchmark run -config=/config/k8s.hcl"]
          volume_mount {
            mount_path = "/config"
            name       = "vault-benchmark-configmap"
          }
          volume_mount {
            mount_path = "/vault-ca"
            name       = "vault-ca"
            read_only  = true
          }
          volume_mount {
            mount_path = "/vault-root-creds"
            name       = "vault-root-creds"
            read_only  = true
          }
          resources {
            limits = {
              memory = "3Gi"
              cpu    = "1700m"
            }
            requests = {
              memory = "2Gi"
              cpu    = "1"
            }
          }
        }
        restart_policy = "Never"
        volume {
          name = "vault-benchmark-configmap"
          config_map {
            name = "vault-benchmark-configmap"
          }
        }
        volume {
          name = "vault-ca"
          secret {
            secret_name = "vault-server-tls"
            items {
              key  = "ca.crt"
              path = "ca.crt"
            }
          }
        }
        volume {
          name = "vault-root-creds"
          secret {
            secret_name = var.root_token_secret_name
            items {
              key  = "root_token"
              path = "root_token"
            }
          }
        }
      }
    }
    backoff_limit = 0
  }
  wait_for_completion = false
  depends_on          = [kubernetes_config_map_v1.vault-benchmark-config]
}