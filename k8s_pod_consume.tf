# Service acccount that would be used by consume pod to authenticate via AWS auth to Vault
resource "kubernetes_service_account" "consume_sa" {
  metadata {
    name = var.consume_pod_sa_name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.consume_pod_role.arn
    }
  }
}

# Assume policy used by consume_pod_role
data "aws_iam_policy_document" "assume_role_consume_pod" {
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
      values   = ["system:serviceaccount:${var.consume_pod_namespace}:${var.consume_pod_sa_name}"]
    }
  }
}


# Role in AWS to allow the consume_pod to authenticate to Vault server via AWS auth method (using IRSA)
resource "aws_iam_role" "consume_pod_role" {

  name               = "consume-pod-role-${random_pet.env.id}"
  assume_role_policy = data.aws_iam_policy_document.assume_role_consume_pod.json

  tags = {
    Name = "consume-pod-role-${random_pet.env.id}"
  }
}

# Consume pod that would login to Vault server via AWS auth and IRSA
resource "kubernetes_pod" "consume_pod" {
  metadata {
    name = "consume-pod"
  }
  spec {
    service_account_name = var.consume_pod_sa_name # The SA has the same name as the AWS role, which would allow omitting of `role=` when login - vault login -method=aws
    container {
      image   = "hashicorp/vault:1.15.6"
      name    = "vault-client"
      command = ["/bin/sh"]
      args    = ["-c", "while true; do echo consume pod; sleep 10;done"]
      env {
        name  = "VAULT_ADDR"
        value = "http://vault-server-${random_pet.env.id}.${var.sa_namespace}:8200" #Name of Helm release
      }
    }

  }
  depends_on = [kubernetes_service_account.consume_sa]
  # Ignoring changes for env variables such as "AWS_ROLE_ARN" which are automaticall injected by K8S
  lifecycle {
    ignore_changes = [spec[0].container[0].env, spec[0].container[0].volume_mount, spec[0].volume]
  }
}
