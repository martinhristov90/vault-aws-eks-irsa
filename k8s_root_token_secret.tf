#Kubernetes secret that hold root token and unseal keys
resource "kubernetes_secret" "root_token_k8s_secret" {
  metadata {
    name      = "vault-root-creds"
    namespace = kubernetes_namespace.k8s-sa-namespace.metadata[0].name
  }

  type = "generic"
}