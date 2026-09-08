#!/usr/bin/env sh

set -x
exec 2>&1

# ---------------------------------------------------------------------------
# postStart hook — runs inside every Vault pod after the container starts.
#
# Flow:
#   Pod *-0  : Initializes Vault on first boot. On all subsequent restarts,
#              fetches the root token from the vault-root-creds K8S secret and
#              runs terraform apply to pick up any changes from git_repository.
#   Pod *-1/2: Waits for vault-root-creds K8S secret to be populated by Pod 0,
#              then writes the root token to ~/.vault-token.
#
# Vault listener readiness:
#   postStart fires immediately when the container starts, before Vault's TCP
#   listener is up. Exit code 1 means connection refused — keep waiting.
#   Exit code 2 (sealed/uninitialized) means the listener is up and we can proceed.
# ---------------------------------------------------------------------------
until vault status > /dev/null 2>&1; VAULT_EXIT=$?; [ $VAULT_EXIT -ne 1 ]; do
  echo "waiting for Vault listener..." > /proc/1/fd/1
  sleep 2
done

# ---------------------------------------------------------------------------
# download_terraform — downloads the Terraform binary to /home/vault if not
# already present. The -f guard makes this safe to call on every pod restart
# without re-downloading when the binary is already on the filesystem.
# PATH is exported by the caller after this function returns, not inside it,
# to guarantee the updated PATH is visible to all subsequent commands in the
# script regardless of sh implementation scoping rules.
# ---------------------------------------------------------------------------
download_terraform() {
  if [ ! -f /home/vault/terraform ]; then
    cd /tmp
    wget https://releases.hashicorp.com/terraform/1.7.4/terraform_1.7.4_linux_amd64.zip || { echo "ERROR: failed to download Terraform" > /proc/1/fd/1; exit 1; }
    unzip terraform_1.7.4_linux_amd64.zip || { echo "ERROR: failed to unzip Terraform" > /proc/1/fd/1; exit 1; }
    rm terraform_1.7.4_linux_amd64.zip
    mv /tmp/terraform /home/vault || { echo "ERROR: failed to move Terraform binary" > /proc/1/fd/1; exit 1; }
  fi
}

# ---------------------------------------------------------------------------
# fetch_root_creds — fetches root token and optionally recovery key from the
# vault-root-creds K8S secret and writes them to ~/.vault-token and
# ~/.vault-recovery-key. Retries until the secret is populated.
# ---------------------------------------------------------------------------
fetch_root_creds() {
  until K8S_SECRET_RESPONSE=$(wget \
        --header="Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
        --no-check-certificate \
        --output-document - --quiet \
        https://kubernetes.default:443/api/v1/namespaces/$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)/secrets/vault-root-creds 2>/dev/null) \
      && VAULT_TOKEN=$(echo "$K8S_SECRET_RESPONSE" | grep -o '"root_token": *"[^"]*"' | cut -d'"' -f4 | base64 -d) \
      && [ -n "$VAULT_TOKEN" ]; do
    echo "Secret vault-root-creds not ready yet, retrying..." > /proc/1/fd/1
    sleep 0.5
  done
  echo "$VAULT_TOKEN" > ~/.vault-token

  VAULT_RECOVERY_KEY=$(echo "$K8S_SECRET_RESPONSE" | grep -o '"recovery_key": *"[^"]*"' | cut -d'"' -f4 | base64 -d)
  if [ -n "$VAULT_RECOVERY_KEY" ]; then
    echo "$VAULT_RECOVERY_KEY" > ~/.vault-recovery-key
  fi
}

case "$VAULT_K8S_POD_NAME" in
  *-0)
    # sys/init always returns HTTP 200 (exit 0) regardless of initialized state;
    # the exit code cannot be used — must check the field value directly.
    if [ "$(vault read -field=initialized sys/init 2>/dev/null)" = "false" ]; then
        # -----------------------------------------------------------------
        # First boot: Vault has never been initialized on this cluster.
        # Initialize Vault with AWS KMS auto-unseal (1 recovery share),
        # capture the root token and recovery key, download Terraform,
        # import the pre-created vault-root-creds K8S secret into TF state,
        # then run apply to fully provision the Vault server configuration.
        # -----------------------------------------------------------------
        echo "Pod *-0: first boot — initializing Vault storage" > /proc/1/fd/1
        vault operator init -recovery-shares=1 -recovery-threshold=1 > /tmp/root.keys

        # Download Terraform binary and export PATH immediately so all subsequent
        # terraform commands (import + apply) can find the binary, especially the import of root creds
        download_terraform
        export PATH=$PATH:/home/vault

        # Write root token to ~/.vault-token so subsequent Vault and TF commands authenticate
        cat /tmp/root.keys | grep "Initial Root Token" | cut -d " " -f4 - > ~/.vault-token
        # Write recovery key to ~/.vault-recovery-key for safekeeping on this pod
        cat /tmp/root.keys | grep "Recovery Key 1" | cut -d " " -f4 > ~/.vault-recovery-key

        # Import the vault-root-creds K8S secret (created empty by TF) into TF state
        # so that apply can populate it with the root token and recovery key.
        # This must only run once — on subsequent restarts the resource is already in state.
        terraform -chdir=/vault/tf-provision import kubernetes_secret.vault_root_creds vault/vault-root-creds > /proc/1/fd/1
        terraform -chdir=/vault/tf-provision apply -input=false -no-color --auto-approve > /proc/1/fd/1
    else
        # -----------------------------------------------------------------
        # Subsequent restarts of Pod *-0: Vault is already initialized.
        # Fetch the root token and recovery key from the vault-root-creds
        # K8S secret (populated during first boot).
        # -----------------------------------------------------------------
        echo "Pod *-0: Vault already initialized — fetching root token and recovery key from vault-root-creds secret" > /proc/1/fd/1
        fetch_root_creds
        if [ ! -f ~/.vault-recovery-key ]; then
          echo "ERROR: recovery_key not found in vault-root-creds secret" > /proc/1/fd/1
          exit 1
        fi
        echo "Vault root token and recovery key successfully retrieved" > /proc/1/fd/1

        # Download Terraform binary (PATH exported below, outside if/else)
        download_terraform
        # On the restart path (else branch), export PATH here so terraform apply below
        # can find the binary. On first boot PATH was already exported inside the if block.
        export PATH=$PATH:/home/vault
        # -------------------------------------------------------------------------
        # Always run terraform apply on Pod *-0, both on first boot and on restarts.
        # Apply is idempotent — safe to run repeatedly. On restarts this picks up
        # any configuration changes pushed to git_repository since the last boot
        # (the init containers already ran git clone and terraform init above).
        # -------------------------------------------------------------------------
        terraform -chdir=/vault/tf-provision apply -input=false -no-color --auto-approve > /proc/1/fd/1
    fi
    ;;
  *)
    # -------------------------------------------------------------------------
    # Pods *-1 and *-2: never initialize Vault.
    # Wait for Pod *-0 to finish init and populate the vault-root-creds K8S
    # secret, then write the root token to ~/.vault-token so the Vault CLI
    # inside this pod is authenticated.
    # -------------------------------------------------------------------------
    echo "Pod $VAULT_K8S_POD_NAME: not Pod *-0, skipping init" > /proc/1/fd/1
    echo "Waiting for vault-root-creds K8S secret to be populated by Pod *-0..." > /proc/1/fd/1
    fetch_root_creds
    echo "Vault root token successfully retrieved" > /proc/1/fd/1
    ;;
esac

echo "vault init was here" > /tmp/init.test
