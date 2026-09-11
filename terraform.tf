terraform {
  required_version = "~>1.16.2"

  required_providers {
    aws = {
      version = "~> 6.64.0"
      source  = "hashicorp/aws"
    }
    helm = {
      version = "~> 3.3.0"
      source  = "hashicorp/helm"
    }
    random = {
      version = "~> 3.9.0"
      source  = "hashicorp/random"
    }
    kubernetes = {
      version = "~> 3.2.1"
      source  = "hashicorp/kubernetes"
    }
  }
}