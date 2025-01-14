resource "kubernetes_manifest" "servicemonitor_vault" {
  count = var.enable_prometheus_servicemonitor ? 1 : 0
  manifest = {
    "apiVersion" = "monitoring.coreos.com/v1"
    "kind"       = "ServiceMonitor"
    "metadata" = {
      "namespace" = "default"
      "labels" = {
        "app.kubernetes.io/instance"   = "vault-prom-crd"
        "app.kubernetes.io/managed-by" = "Helm"
        "app.kubernetes.io/name"       = "vault"
        "helm.sh/chart"                = "vault-0.28.1"
        "release"                      = "prometheus"
      }
      "name" = "vault-vault-server-${random_pet.env.id}"
    }
    "spec" = {
      "endpoints" = [
        {
          "interval" = "10s"
          "params" = {
            "format" = [
              "prometheus",
            ]
          }
          "path"          = "/v1/sys/metrics"
          "port"          = "http"
          "scheme"        = "http"
          "scrapeTimeout" = "10s"
          "tlsConfig" = {
            "insecureSkipVerify" = true
          }
        },
      ]
      "namespaceSelector" = {
        "matchNames" = [
          "vault",
        ]
      }
      "selector" = {
        "matchLabels" = {
          "app.kubernetes.io/instance" = "vault-server-${random_pet.env.id}"
          "app.kubernetes.io/name"     = "vault"
          "vault-active"               = "true"
        }
      }
    }
  }
}