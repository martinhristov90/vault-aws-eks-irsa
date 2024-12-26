#Creating a service with predictable names (the name of services depends of the name of the Helm release) to be used for Vault benchmark tool

resource "kubernetes_service" "example" {
  metadata {
    name = "vault-benchmark-service"
    namespace = "vault"
  }
  spec {
    selector = {
      "app.kubernetes.io/instance" = "vault-server-${random_pet.env.id}",
      "app.kubernetes.io/name" = "vault",
      "component"="server"
    }
    session_affinity = "ClientIP"
    port {
      port        = 8200
      target_port = 8200
    }

    type = "ClusterIP"
  }
}