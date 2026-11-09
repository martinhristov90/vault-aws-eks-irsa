output "identity-oidc-issuer" {
  value = local.issuer_hostpath
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate used for the Vault ingress (empty when ingress is disabled)"
  value       = var.ingress_enable ? module.acm_ingress[0].certificate_arn : ""
}

output "vault_ingress_hostname" {
  description = "Public FQDN / hostname configured for the Vault Ingress (empty when ingress is disabled)"
  value       = var.ingress_enable ? local.ingress_hostname : ""
}

output "vault_ingress_lb_name" {
  description = "Name of the AWS Application Load Balancer created for the Vault Ingress (empty when ingress is disabled)"
  value       = var.ingress_enable ? local.ingress_lb_name : ""
}

