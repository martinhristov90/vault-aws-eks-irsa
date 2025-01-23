# Module that utilizes ACM to create a publicly trusted cert for Ingress resource
module "acm_ingress" {
  count               = var.ingress_enable ? 1 : 0
  source              = "./modules/acm_ingress"
  ingress_hosted_zone = var.ingress_hosted_zone
  ingress_lb_name     = var.ingress_lb_name
}