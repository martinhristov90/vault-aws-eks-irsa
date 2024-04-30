provider "aws" {
  region = var.aws_region
}
#The current K8S context would be used
provider "kubernetes" {
  config_path = "~/.kube/config"
}
#The current K8S context would be used
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}