#!/usr/bin/env sh

set -x
sleep 3
if [[ $VAULT_K8S_POD_NAME =~ "^.+0$" ]]; then
    if [[ $(vault read -field=initialized /sys/init) == "false" ]]; then
        echo "the VAULT_K8S_POD_NAME ends with 0, this is the first Pod of the StatefulSet, initalizing the storage" > /proc/1/fd/1 
        vault operator init -recovery-shares=1 -recovery-threshold=1 > /tmp/root.keys
        cd /tmp
        wget https://releases.hashicorp.com/terraform/1.7.4/terraform_1.7.4_linux_amd64.zip
        unzip terraform_1.7.4_linux_amd64.zip
        rm terraform_1.7.4_linux_amd64.zip
        mv /tmp/terraform /home/vault
        PATH=$PATH:/home/vault
        cat /tmp/root.keys | grep "Initial Root Token" | cut -d " " -f4 - > ~/.vault-token
        cat /tmp/root.keys | grep "Recovery Key 1" | cut -d " " -f4 > ~/.vault-recovery-key
        terraform -chdir=/vault/tf-provision import kubernetes_secret.vault_root_creds vault/vault-root-creds > /proc/1/fd/1
        terraform -chdir=/vault/tf-provision apply -input=false -no-color --auto-approve > /proc/1/fd/1
    else
        echo "Vault is already initialized" > /proc/1/fd/1
        echo "Vault is already initialized, grabbing the vault root token from K8S secret vault-root-creds and setting at home directory" > /proc/1/fd/1
        wget --header="Authorization: Bearer "$(cat /var/run/secrets/kubernetes.io/serviceaccount/token) --no-check-certificate --output-document - --quiet https://kubernetes.default:443/api/v1/namespaces/vault/secrets/vault-root-creds | grep root_token | tail -1 | awk -F"\"" '{print $4}' | base64 -d > ~/.vault-token
    fi
else
    echo "This Pod is not supposed to initialize the storage, skipping init" > /proc/1/fd/1
fi

echo "vault init was here" > /tmp/init.test