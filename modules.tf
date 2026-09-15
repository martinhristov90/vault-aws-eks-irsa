# Module that utilizes ACM to create a publicly trusted cert for Ingress resource
module "acm_ingress" {
  count               = var.ingress_enable ? 1 : 0
  source              = "./modules/acm_ingress"
  ingress_hosted_zone = var.ingress_hosted_zone
  ingress_lb_name     = var.ingress_lb_name
}

# Module that deploys the Vault benchmark service and job
module "vault_benchmark" {
  count                  = var.enable_vault_benchmark ? 1 : 0
  source                 = "./modules/vault_benchmark"
  namespace              = kubernetes_namespace_v1.k8s-sa-namespace.metadata[0].name
  root_token_secret_name = kubernetes_secret_v1.root_token_k8s_secret.metadata[0].name
  vault_release_name     = "vault-server-${random_pet.env.id}"

  # Ensure the benchmark only starts after Vault is fully initialised and the
  # in-container Terraform apply (postStart) has finished populating the
  # vault-root-creds secret. helm_release.vault_server uses wait=true, so it
  # only completes once all pods are Ready — postStart must complete before a
  # pod becomes Ready, giving us the ordering guarantee we need.
  depends_on = [helm_release.vault_server]
}