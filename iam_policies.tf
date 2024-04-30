#Creating policy to allow the K8S SA (SA_NAME) to assume to assume IAM role
data "aws_iam_policy_document" "assume_role_vault_server_eks" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]


    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.issuer_hostpath}:sub"
      values   = ["system:serviceaccount:${var.sa_namespace}:${var.sa_name}"]
    }
  }
}

data "aws_iam_policy_document" "vault_kms_unseal" {
  statement {
    sid       = "vaultPolicyDocumentKMSUnseal"
    effect    = "Allow"
    resources = [aws_kms_key.vault_server_kms_key.arn]

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
  }
}

# Creating a managed policy for KMS auto unseal feature
resource "aws_iam_policy" "vault_kms_auto_unseal_policy" {
  name        = "vault-policy-kms-unseal-${random_pet.env.id}"
  path        = "/"
  description = "Policy that provides the needed KMS permission for Vault server's auto unseal feature"

  policy = data.aws_iam_policy_document.vault_kms_unseal.json
}

# Policy document (only in TF) that gives permissions to use AWS auth method
data "aws_iam_policy_document" "vault_aws_auth" {
  statement {
    sid       = "vaultPolicyDocumentVaultAWSAuth"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ec2:DescribeInstances",
      "iam:GetInstanceProfile",
      "iam:GetUser",
      "iam:GetRole"
    ]
  }
}
# Creating a managed policy for AWS auth method
resource "aws_iam_policy" "vault_aws_auth_policy" {
  name        = "vault-policy-vault-aws-auth-${random_pet.env.id}"
  path        = "/"
  description = "Policy that provides the needed permissions for the Vault server to verify users via the AWS authentication method (iam type)"

  policy = data.aws_iam_policy_document.vault_aws_auth.json
}

# Policy document (only in TF) that gives needed permissions for AWS secrets engine
data "aws_iam_policy_document" "vault_aws_secret" {
  statement {
    sid       = "vaultPolicyDocumentVaultAWSSecret"
    effect    = "Allow"
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.id}:user/vault-*"]

    actions = [
      "iam:AttachUserPolicy",
      "iam:CreateAccessKey",
      "iam:CreateUser",
      "iam:DeleteAccessKey",
      "iam:DeleteUser",
      "iam:DeleteUserPolicy",
      "iam:DetachUserPolicy",
      "iam:ListAccessKeys",
      "iam:ListAttachedUserPolicies",
      "iam:ListGroupsForUser",
      "iam:ListUserPolicies",
      "iam:PutUserPolicy",
      "iam:AddUserToGroup",
      "iam:RemoveUserFromGroup"
    ]
  }
}

# Creating a managed policy for AWS secrets engine
resource "aws_iam_policy" "vault_aws_secret_policy" {
  name        = "vault-policy-vault-aws-secret-${random_pet.env.id}"
  path        = "/"
  description = "Policy that provides the needed permissions for the Vault server's aws secrets engine to function properly"

  policy = data.aws_iam_policy_document.vault_aws_secret.json
}


