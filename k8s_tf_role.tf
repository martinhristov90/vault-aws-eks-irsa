#K8S role to create K8S secret used for storing root token and recovery keys
resource "kubernetes_role" "role_root_token_unseal_key" {
  metadata {
    name      = "update-k8s-secrets-vault-${random_pet.env.id}"
    namespace = kubernetes_namespace.k8s-sa-namespace.metadata[0].name
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
    namespace = kubernetes_namespace.k8s-sa-namespace.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.role_root_token_unseal_key.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = var.sa_name
    namespace = var.sa_namespace
  }
}

# Role scoped to the Terraform kubernetes backend tfstate secret only.
# Name follows the backend's fixed convention: tfstate-<workspace>-<secret_suffix>
# where workspace=default and secret_suffix=tf-provision-state.
resource "kubernetes_role" "role_tf_state" {
  metadata {
    name      = "vault-tf-state-access-${random_pet.env.id}"
    namespace = kubernetes_namespace.k8s-sa-namespace.metadata[0].name
    labels = {
      test = "vault-${random_pet.env.id}"
    }
  }

  # create and list cannot be scoped to resource_names in K8S RBAC.
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create", "list"]
  }

  # get/update/patch/delete are scoped to the specific tfstate secret name.
  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = ["tfstate-default-tf-provision-state"]
    verbs          = ["get", "update", "patch", "delete"]
  }

  # The Terraform kubernetes backend uses a Lease object for state locking.
  # create cannot be scoped to resource_names (resource does not exist yet at create time).
  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["create"]
  }

  # get/update/delete are scoped to the specific lease name.
  rule {
    api_groups     = ["coordination.k8s.io"]
    resources      = ["leases"]
    resource_names = ["lock-tfstate-default-tf-provision-state"]
    verbs          = ["get", "update", "delete"]
  }
}

# RoleBinding for tfstate secret access
resource "kubernetes_role_binding" "role_tf_state_role_binding" {
  metadata {
    name      = "vault-tf-state-rolebinding"
    namespace = kubernetes_namespace.k8s-sa-namespace.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.role_tf_state.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = var.sa_name
    namespace = var.sa_namespace
  }
}
