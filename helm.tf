resource "helm_release" "vault_server" {
  name       = "vault-server-${random_pet.env.id}"
  repository = "https://helm.releases.hashicorp.com  "
  chart      = "hashicorp/vault"
  namespace  = kubernetes_namespace.k8s-sa-namespace.metadata[0].name
  version    = var.vault_helm_chart_version
  wait       = true #Waiting for all Vault Pods to be Ready state before marking TF success
  #The capital letter variables are used by TF init container
  #Lower case variables are used by the Vault Helm chart
  values = [
    "${templatefile("./values_vault.yaml", {
      TF_VAR_DEMOROLE_POLICY_ARN       = var.DEMOROLE_POLICY_ARN
      TF_VAR_DEMOROLE_ROLE_ARN         = var.DEMOROLE_ROLE_ARN
      TF_VAR_ROLE_NAME                 = aws_iam_role.consume_pod_role.name # Name of the role matches the role used by Consume Pod
      TF_VAR_ALLOWED_ARN_ROLE_LOGIN    = aws_iam_role.consume_pod_role.arn  # Allow consume pod to login
      TF_VAR_INFERRED_AWS_REGION       = var.INFERRED_AWS_REGION
      TF_VAR_BOUND_VPC_IDS             = var.BOUND_VPC_IDS
      vault_version_and_type           = local.vault_version_and_type
      vault_repository                 = local.vault_repository
      ingress_enable                   = var.ingress_enable
      ingress_lb_name                  = var.ingress_lb_name
      ingress_hosted_zone              = var.ingress_hosted_zone
      enable_prometheus_servicemonitor = var.enable_prometheus_servicemonitor
      k8s_cluster_name                 = var.k8s_cluster_name
      sa_name                          = var.sa_name
      vault_server_aws_role            = aws_iam_role.vault_eks_server_role.arn
      kms_key_id                       = aws_kms_key.vault_server_kms_key.id # AWS KMS key used for seal/unseal
      git_repository                   = var.git_repository
    })}"
  ]
  depends_on = [kubernetes_secret.vault-ent-license, module.acm_ingress]
}