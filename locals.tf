locals {
  #Fetching the OIDC provider hostpath, used for creating Trust relation AssumeWithWebIdentity roles
  issuer_hostpath = trimprefix(data.aws_eks_cluster.k8s_cluster_info.identity[0].oidc[0].issuer, "https://")
  provider_arn    = format("arn:aws:iam::%s:oidc-provider/%s", data.aws_caller_identity.current.account_id, local.issuer_hostpath)
}
