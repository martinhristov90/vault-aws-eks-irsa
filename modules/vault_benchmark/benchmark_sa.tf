#Creating a service with predictable name (the name of services depends of the name of the Helm release) to be used for Vault benchmark tool
resource "kubernetes_service_v1" "vault_benchmark" {
  metadata {
    name      = local.vault_service_name
    namespace = var.namespace
  }
  spec {
    selector = {
      "app.kubernetes.io/instance" = var.vault_release_name,
      "app.kubernetes.io/name"     = "vault",
      "component"                  = "server"
    }
    session_affinity = "ClientIP"
    port {
      port        = 8200
      target_port = 8200
    }
    type = "ClusterIP"
  }
}