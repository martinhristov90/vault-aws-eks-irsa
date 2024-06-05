#In case the K8S namespace specified via var.sa_namespace does not exists, it has to be created
resource "kubernetes_namespace" "k8s-sa-namespace" {
  count = contains(data.kubernetes_all_namespaces.allns.namespaces, var.sa_namespace) ? 0 : 1
  metadata {
    labels = {
      environment_id = "${random_pet.env.id}"
    }
    name = var.sa_namespace
  }
}