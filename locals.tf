locals {
  # Predictable Ingress hostname and ALB name derived from the Helm chart's deployment namespace (var.sa_namespace)
  ingress_hostname = var.sa_namespace == "vault" ? "vault.${var.ingress_hosted_zone}" : "${var.sa_namespace}.${var.ingress_hosted_zone}"
  ingress_lb_name  = var.sa_namespace == "vault" ? var.ingress_lb_name : substr("${var.ingress_lb_name}-${var.sa_namespace}", 0, 32)

  # Fetching the OIDC provider hostpath, used for creating Trust relation AssumeWithWebIdentity roles
  issuer_hostpath        = trimprefix(data.aws_eks_cluster.k8s_cluster_info.identity[0].oidc[0].issuer, "https://")
  provider_arn           = format("arn:aws:iam::%s:oidc-provider/%s", data.aws_caller_identity.current.account_id, local.issuer_hostpath)
  vault_version_and_type = "${var.vault_version}${var.vault_type == "ent" ? "-ent" : ""}"
  vault_repository       = var.vault_type == "ent" ? "hashicorp/vault-enterprise" : "hashicorp/vault"
}