resource "aws_acm_certificate" "mycert_acm" {
  domain_name               = "vault.${var.ingress_hosted_zone}"
  subject_alternative_names = ["*.vault.${var.ingress_hosted_zone}"]

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "selected_zone" {
  name         = var.ingress_hosted_zone
  private_zone = false
}

#Getting information about the ALB created by the Vault's Helm chart
#data "aws_lb" "ingress_lb" {
#  name = var.ingress_lb_name
#  depends_on = [aws_acm_certificate_validation.cert_validation,helm_release.vault_server]
#}
#
#resource "aws_route53_record" "vault_lb_a_record" {
#  zone_id = data.aws_route53_zone.selected_zone.zone_id
#  name    = "vault.${var.ingress_hosted_zone}"
#  type    = "A"
#
#  alias {
#    name                   = data.aws_lb.ingress_lb.dns_name
#    zone_id                = data.aws_lb.ingress_lb.zone_id
#    evaluate_target_health = true
#  }
#
#  depends_on = [aws_acm_certificate_validation.cert_validation,helm_release.vault_server]
#}

resource "aws_route53_record" "cert_validation_record" {
  for_each = {
    for dvo in aws_acm_certificate.mycert_acm.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.selected_zone.zone_id
}

resource "aws_acm_certificate_validation" "cert_validation" {
  timeouts {
    create = "5m"
  }
  certificate_arn         = aws_acm_certificate.mycert_acm.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation_record : record.fqdn]
}
