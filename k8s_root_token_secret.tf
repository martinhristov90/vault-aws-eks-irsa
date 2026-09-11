#Kubernetes secret that hold root token and unseal keys
resource "kubernetes_secret_v1" "root_token_k8s_secret" {
  metadata {
    name      = "vault-root-creds"
    namespace = kubernetes_namespace_v1.k8s-sa-namespace.metadata[0].name
  }

  type = "generic"
}