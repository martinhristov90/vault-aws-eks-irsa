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

