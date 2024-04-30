#K8S Configmap which contains bash script for provisioning Vault via TF
resource "kubernetes_config_map" "vault_init_config" {
  metadata {
    name      = "vault-init-config"
    namespace = var.sa_namespace
  }

  data = {
    "run.sh" = "${file("${path.module}/run.sh")}"
  }
}