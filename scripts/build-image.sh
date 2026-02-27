#!/bin/bash
# Build OpenClaw Docker image and push to Azure Container Registry using ACR Tasks.
set -euo pipefail

ACR_NAME="${1:-}"
IMAGE_TAG="${2:-latest}"
OPENCLAW_VERSION="${3:-main}"

if [ -z "${ACR_NAME}" ]; then
  ACR_NAME="$(azd env get-values | awk -F= '/^CONTAINER_REGISTRY_NAME=/{gsub(/"/,"",$2);print $2}')"
fi

if [ -z "${ACR_NAME}" ]; then
  echo "ERROR: Container registry name not found. Run 'azd provision' first." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE_PATH="${SCRIPT_DIR}/../src/moltbot/Dockerfile"
BUILD_CONTEXT="${SCRIPT_DIR}/../src/moltbot"

echo "Building image 'clawdbot:${IMAGE_TAG}' in ACR '${ACR_NAME}'"
az acr build \
  --registry "${ACR_NAME}" \
  --image "clawdbot:${IMAGE_TAG}" \
  --file "${DOCKERFILE_PATH}" \
  --build-arg "OPENCLAW_VERSION=${OPENCLAW_VERSION}" \
  "${BUILD_CONTEXT}"

echo "Image build complete"
