variable "ingress_hosted_zone" {
  type    = string
  default = "mhristov.sbx.hashidemos.io"
}

variable "ingress_lb_name" {
  type    = string
  default = "marti-test-alb-vault-k8s"
}

variable "ingress_hostname" {
  type        = string
  description = "Domain name for the ACM certificate and Ingress host"
  default     = ""
}