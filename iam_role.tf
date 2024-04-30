# Creating a role used by the Vault server used in EKS
resource "aws_iam_role" "vault_eks_server_role" {

  name               = "vault-eks-server-role-${random_pet.env.id}"
  assume_role_policy = data.aws_iam_policy_document.assume_role_vault_server_eks.json

  managed_policy_arns = [aws_iam_policy.vault_kms_auto_unseal_policy.arn, aws_iam_policy.vault_aws_auth_policy.arn, aws_iam_policy.vault_aws_secret_policy.arn]

  tags = {
    Name = "vault-server-eks-role-kms-secrets-auth-${random_pet.env.id}"
  }
}