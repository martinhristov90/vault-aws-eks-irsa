#In case the K8S namespace specified via var.vault_namespace does not exists, it has to be created
resource "kubernetes_namespace_v1" "k8s-sa-namespace" {
  metadata {
    labels = {
      environment_id = "${random_pet.env.id}"
    }
    name = var.vault_namespace
  }
}