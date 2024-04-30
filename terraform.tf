terraform {
  required_version = "~>1.8.2"

  required_providers {
    aws = {
      version = "~> 4.20.1"
      source  = "hashicorp/aws"
    }
    helm = {
      version = "~> 2.13.1"
      source  = "hashicorp/helm"
    }
    random = {
      version = "~> 3.3.2"
      source  = "hashicorp/random"
    }
    kubernetes = {
      version = "~> 2.29.0"
      source  = "hashicorp/kubernetes"
    }
  }
}