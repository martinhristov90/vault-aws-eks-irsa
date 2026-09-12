# Generating CA private key
resource "tls_private_key" "ca_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Generating CA
resource "tls_self_signed_cert" "ca_cert" {
  private_key_pem   = tls_private_key.ca_key.private_key_pem
  is_ca_certificate = true


  subject {
    common_name  = "Vault IRSA raft setup"
    organization = "IBM"
  }

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "cert_signing",
    "crl_signing"
  ]
}

# Key for the Vault servers
resource "tls_private_key" "vault_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# CSR for vault servers
resource "tls_cert_request" "vault_csr" {
  private_key_pem = tls_private_key.vault_key.private_key_pem

  subject {
    common_name  = "vault-server"
    organization = "IBM"
  }


  dns_names = [
    "localhost",
    "127.0.0.1",


    "vault-server-${random_pet.env.id}",
    "vault-server-${random_pet.env.id}.${var.sa_namespace}",
    "vault-server-${random_pet.env.id}.${var.sa_namespace}.svc",
    "vault-server-${random_pet.env.id}.${var.sa_namespace}.svc.cluster.local",


    "*.vault-server-${random_pet.env.id}-internal",
    "*.vault-server-${random_pet.env.id}-internal.${var.sa_namespace}",
    "*.vault-server-${random_pet.env.id}-internal.${var.sa_namespace}.svc.cluster.local",


    "*.${var.sa_namespace}",
    "*.${var.sa_namespace}.svc",
    "*.${var.sa_namespace}.svc.cluster.local"
  ]

  ip_addresses = [
    "127.0.0.1"
  ]
}

# Signing the Vault server cert with the CA
resource "tls_locally_signed_cert" "vault_cert" {
  cert_request_pem   = tls_cert_request.vault_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 17520 # 2 years

  allowed_uses = [
    "server_auth",
    "client_auth"
  ]
}

# Putting the cert in K8S secret
resource "kubernetes_secret_v1" "vault_tls" {
  metadata {
    name      = "vault-server-tls"
    namespace = var.sa_namespace
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = "${tls_locally_signed_cert.vault_cert.cert_pem}\n${tls_self_signed_cert.ca_cert.cert_pem}" # TLS cert + CA
    "tls.key" = tls_private_key.vault_key.private_key_pem
    "ca.crt"  = tls_self_signed_cert.ca_cert.cert_pem
  }
}

# Creates a secret only with the CA to be consumed by customers of Vault, mainly consume-pod
resource "kubernetes_secret_v1" "vault_ca_default" {
  metadata {
    name      = "vault-ca-cert"
    namespace = "default" # CA secret will be located in the default namespace to be consumed by customers of Vault
  }

  type = "Opaque"

  data = {
    # Getting only the CA cert
    "ca.crt" = tls_self_signed_cert.ca_cert.cert_pem
  }
}