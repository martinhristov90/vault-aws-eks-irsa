#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

POD_NAMESPACE="${POD_NAMESPACE:-default}"
POD_NAME="${POD_NAME:-}"
REMOTE_PATH="/tmp/vault-go-consumer"

echo "================================================================"
echo " Upload and Run Go Vault Example on Consume Pod"
echo "================================================================"

# 1. Discover or verify pod name
if [ -z "${POD_NAME}" ]; then
  echo "==> Discovering consume pod in namespace '${POD_NAMESPACE}'..."
  POD_NAME=$(kubectl get pods -n "${POD_NAMESPACE}" --no-headers -o custom-columns=":metadata.name" 2>/dev/null | grep '^consume-pod' | head -n 1 || true)
  if [ -z "${POD_NAME}" ]; then
    echo "Error: Could not find any pod starting with 'consume-pod' in namespace '${POD_NAMESPACE}'."
    echo "Please ensure the pod is deployed or specify POD_NAME explicitly."
    exit 1
  fi
  echo "==> Found consume pod: ${POD_NAME}"
else
  echo "==> Using specified pod: ${POD_NAME}"
fi

echo "Target Pod:       ${POD_NAME}"
echo "Target Namespace: ${POD_NAMESPACE}"

# 2. Check if pod is running
echo "==> Verifying pod '${POD_NAME}' in namespace '${POD_NAMESPACE}'..."
if ! kubectl get pod "${POD_NAME}" -n "${POD_NAMESPACE}" >/dev/null 2>&1; then
  echo "Error: Pod '${POD_NAME}' not found in namespace '${POD_NAMESPACE}'."
  echo "Please check if the pod is deployed and 'kubectl' is configured properly."
  exit 1
fi

POD_PHASE=$(kubectl get pod "${POD_NAME}" -n "${POD_NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
if [ "${POD_PHASE}" != "Running" ]; then
  echo "Warning: Pod '${POD_NAME}' is currently in '${POD_PHASE}' state (expected 'Running')."
fi

# 3. Detect Pod architecture
NODE_NAME=$(kubectl get pod "${POD_NAME}" -n "${POD_NAMESPACE}" -o jsonpath='{.spec.nodeName}' 2>/dev/null || true)

ARCH="amd64"
if [ -n "${NODE_NAME}" ]; then
  ARCH=$(kubectl get node "${NODE_NAME}" -o jsonpath='{.status.nodeInfo.architecture}' 2>/dev/null || echo "amd64")
fi
echo "==> Detected architecture: ${ARCH}"

# 4. Build binary
echo "==> Building binary for Linux/${ARCH}..."
./build.sh "${ARCH}"

# 5. Upload binary to pod
echo "==> Uploading binary to ${POD_NAME}:${REMOTE_PATH}..."
kubectl cp "${SCRIPT_DIR}/bin/vault-go-consumer" "${POD_NAMESPACE}/${POD_NAME}:${REMOTE_PATH}"

# 6. Make binary executable
kubectl exec -n "${POD_NAMESPACE}" "${POD_NAME}" -- chmod +x "${REMOTE_PATH}"

# 7. Execute binary inside the pod
echo "==> Executing Go consumer inside ${POD_NAME}..."
echo "----------------------------------------------------------------"
kubectl exec -it -n "${POD_NAMESPACE}" "${POD_NAME}" -- "${REMOTE_PATH}"
