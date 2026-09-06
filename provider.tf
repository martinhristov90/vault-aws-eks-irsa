provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.k8s_cluster_info.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.k8s_cluster_info.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.k8s_cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.k8s_cluster_info.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.k8s_cluster_info.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.k8s_cluster_name, "--region", var.aws_region]
    }
  }
}