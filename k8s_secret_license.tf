resource "kubernetes_secret" "vault-ent-license" {
  metadata {
    name      = "vault-ent-license"
    namespace = kubernetes_namespace.k8s-sa-namespace.metadata[0].name
  }

  data = {
    license = file("license_vault.txt")
  }

  type = "generic"
}