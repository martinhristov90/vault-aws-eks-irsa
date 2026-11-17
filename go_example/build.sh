#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

OUTPUT_DIR="${SCRIPT_DIR}/bin"
mkdir -p "${OUTPUT_DIR}"

TARGET_ARCH="${1:-amd64}"

echo "==> Building static Go binary for Linux/${TARGET_ARCH}..."
CGO_ENABLED=0 GOOS=linux GOARCH="${TARGET_ARCH}" go build -ldflags="-s -w" -o "${OUTPUT_DIR}/vault-go-consumer" main.go

echo "==> Build successful: ${OUTPUT_DIR}/vault-go-consumer"
ls -lh "${OUTPUT_DIR}/vault-go-consumer"
