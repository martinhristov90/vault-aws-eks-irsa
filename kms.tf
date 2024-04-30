#KMS key used for seal/unseal
resource "aws_kms_key" "vault_server_kms_key" {
  description             = "Vault Server Key ${random_pet.env.id}"
  deletion_window_in_days = 10
}