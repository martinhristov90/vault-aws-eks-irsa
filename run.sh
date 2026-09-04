#!/usr/bin/env sh

set -x
# postStart fires immediately when the container starts, before Vault's listener
# is up. Exit code 1 means connection refused — keep waiting.
# Exit code 2 (sealed/uninitialized) means the listener is up and we can proceed.
until vault status > /dev/null 2>&1; VAULT_EXIT=$?; [ $VAULT_EXIT -ne 1 ]; do
  echo "waiting for Vault listener..." > /proc/1/fd/1
  sleep 2
done
case "$VAULT_K8S_POD_NAME" in
  *-0)
    # sys/init always returns HTTP 200 (exit 0) regardless of state;
    # must check the field value, not the exit code
    if [ "$(vault read -field=initialized sys/init 2>/dev/null)" = "false" ]; then
        echo "the VAULT_K8S_POD_NAME ends with 0, this is the first Pod of the StatefulSet, initalizing the storage" > /proc/1/fd/1 
        vault operator init -recovery-shares=1 -recovery-threshold=1 > /tmp/root.keys
        cd /tmp
        wget https://releases.hashicorp.com/terraform/1.7.4/terraform_1.7.4_linux_amd64.zip || { echo "ERROR: failed to download Terraform" > /proc/1/fd/1; exit 1; }
        unzip terraform_1.7.4_linux_amd64.zip || { echo "ERROR: failed to unzip Terraform" > /proc/1/fd/1; exit 1; }
        rm terraform_1.7.4_linux_amd64.zip
        mv /tmp/terraform /home/vault || { echo "ERROR: failed to move Terraform binary" > /proc/1/fd/1; exit 1; }
        PATH=$PATH:/home/vault
        cat /tmp/root.keys | grep "Initial Root Token" | cut -d " " -f4 - > ~/.vault-token
        cat /tmp/root.keys | grep "Recovery Key 1" | cut -d " " -f4 > ~/.vault-recovery-key
        terraform -chdir=/vault/tf-provision import kubernetes_secret.vault_root_creds vault/vault-root-creds > /proc/1/fd/1
        terraform -chdir=/vault/tf-provision apply -input=false -no-color --auto-approve > /proc/1/fd/1
    fi
    ;;
  *)
    echo "This Pod is not supposed to initialize the storage, skipping init" > /proc/1/fd/1
    echo "Waiting for K8S secret vault-root-creds to become available..." > /proc/1/fd/1
    until VAULT_TOKEN=$(wget --header="Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
         --no-check-certificate \
         --output-document - --quiet \
         https://kubernetes.default:443/api/v1/namespaces/vault/secrets/vault-root-creds 2>/dev/null \
    | grep -o '"root_token": *"[^"]*"' | cut -d'"' -f4 | base64 -d) && [ -n "$VAULT_TOKEN" ]; do
      echo "Secret vault-root-creds not ready yet, retrying..." > /proc/1/fd/1
      sleep 0.5
    done
    echo "$VAULT_TOKEN" > ~/.vault-token
    echo "Vault root token successfully retrieved" > /proc/1/fd/1
    ;;
esac

echo "vault init was here" > /tmp/init.test