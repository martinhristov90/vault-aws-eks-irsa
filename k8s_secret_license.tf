resource "kubernetes_secret_v1" "vault-ent-license" {
  metadata {
    name      = "vault-ent-license"
    namespace = kubernetes_namespace_v1.k8s-sa-namespace.metadata[0].name
  }

  data = {
    license = file("license_vault.txt")
  }

  type = "generic"
}