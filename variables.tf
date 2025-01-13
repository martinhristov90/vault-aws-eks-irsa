variable "k8s_cluster_name" {
  type        = string
  description = "Name of K8S cluster in AWS (EKS)"
}

variable "aws_region" {
  description = "AWS region where the EKS cluster is located"
}

variable "sa_name" {
  description = "Name of K8S SA used by the Vault server StatefulSet, it is also set in the Vault's Helm chart"
  default     = "vault-server"
}

variable "sa_namespace" {
  description = "K8S namespace of the K8S SA"
  default     = "vault"
}

variable "consume_pod_namespace" {
  default     = "default"
  description = "K8S namespace of consume pod"
}

variable "consume_pod_sa_name" {
  default     = "demo-sa"
  description = "Name of SA used by consume Pod"
}

variable "vault_helm_chart_version" {
  default     = "0.28.0"
  description = "Version of the Vault helm chart to be used"
}

variable "vault_version" {
  default     = "1.18.2"
  description = "Version of Vault used by the Helm chart"

  validation {
    condition     = can(regex("^([0-9]\\.[0-9]{1,2}?\\.[0-9]{1,2}?)$", var.vault_version))
    error_message = "The version of Vault should be in following format 1.18.2"
  }
}

variable "vault_type" {
  default     = "ent"
  description = "Whether Vault should be OSS or ENT"

  validation {
    condition     = can(regex("^(ent|oss)$", var.vault_type))
    error_message = "The type should be either \"ent\" or \"oss\""
  }
}

variable "DEMOROLE_POLICY_ARN" {
  description = "ARN of DEMOROLE to be used by Vault AWS secret engine, used by TF init container"
}

variable "DEMOROLE_ROLE_ARN" {
  description = "Role ARN used by AWS secret, used by TF init container"
}

variable "INFERRED_AWS_REGION" {
  description = "Inferred region for AWS auth method, used by TF init container"
}

variable "BOUND_VPC_IDS" {
  description = "VPC allowed to login, used by TF init container"
}

variable "git_repository" {
  description = "Git repository containing TF configuration to be deployed in EKS"
  default     = "https://github.com/martinhristov90/terraform-aws-k8s-vault-setup"
}