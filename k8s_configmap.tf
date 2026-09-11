#K8S Configmap which contains bash script for provisioning Vault via TF
resource "kubernetes_config_map_v1" "vault_init_config" {
  metadata {
    name      = "vault-init-config"
    namespace = kubernetes_namespace_v1.k8s-sa-namespace.metadata[0].name
  }

  data = {
    "run.sh" = file("${path.module}/run.sh")
  }
}