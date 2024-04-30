#K8S role to create K8S secret used for storing root token and recovery keys
resource "kubernetes_role" "role_root_token_unseal_key" {
  metadata {
    name      = "update-k8s-secrets-vault-${random_pet.env.id}"
    namespace = var.sa_namespace
    labels = {
      test = "vault-${random_pet.env.id}"
    }
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = ["vault-root-creds"]
    verbs          = ["create", "get", "patch"]
  }
}
#Rolebinding for the role above
resource "kubernetes_role_binding" "role_root_token_unseal_key_role_binding" {
  metadata {
    name      = "vault-server-k8s-secrets-rolebinding"
    namespace = var.sa_namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "update-k8s-secrets-vault-${random_pet.env.id}"
  }
  subject {
    kind      = "ServiceAccount"
    name      = var.sa_name
    namespace = var.sa_namespace
  }
}