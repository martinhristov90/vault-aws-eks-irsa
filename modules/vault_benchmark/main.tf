variable "namespace" {
  description = "K8S namespace where the Vault benchmark resources will be deployed"
  type        = string
}

variable "root_token_secret_name" {
  description = "Name of the K8S secret that holds the Vault root token (key: root_token)"
  type        = string
  default     = "vault-root-creds"
}

variable "vault_release_name" {
  description = "Name of the Vault Helm release — used to build the StatefulSet selector label (app.kubernetes.io/instance)"
  type        = string
}

locals {
  vault_service_name = "vault-benchmark-service"
}





