#Creating a service with predictable name (the name of services depends of the name of the Helm release) to be used for Vault benchmark tool

resource "kubernetes_service" "vault_benchmark" {
  metadata {
    name      = "vault-benchmark-service"
    namespace = kubernetes_namespace.k8s-sa-namespace.metadata[0].name
  }
  spec {
    selector = {
      "app.kubernetes.io/instance" = "vault-server-${random_pet.env.id}",
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