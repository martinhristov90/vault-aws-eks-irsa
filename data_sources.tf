data "aws_eks_cluster" "k8s_cluster_info" {
  name = var.k8s_cluster_name
}
#Getting info of the current AWS account
data "aws_caller_identity" "current" {}

#Getting all namespaces to check if var.sa_namespace exists
data "kubernetes_all_namespaces" "allns" {}
