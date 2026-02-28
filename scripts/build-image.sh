#!/bin/bash
# Build OpenClaw Docker image and push to Azure Container Registry using ACR Tasks.
#
# Two-stage build:
#   1. Base image (clawdbot-base:<tag>) — OS deps, OpenClaw source, patches, pnpm build.
#      Only rebuilt when OPENCLAW_VERSION or patch files change (~4 min).
#   2. Final image (clawdbot:<tag>) — runtime scripts layered on the base (~10 sec).
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
BUILD_CONTEXT="${SCRIPT_DIR}/../src/moltbot"
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

# ---------------------------------------------------------------------------
# Compute base image tag from OPENCLAW_VERSION + patch file content hashes.
# ---------------------------------------------------------------------------
hash_input() {
  printf '%s' "${OPENCLAW_VERSION}"
  cat "${BUILD_CONTEXT}/patch-whatsapp-515.cjs" "${BUILD_CONTEXT}/patch-browser-timeouts.cjs"
}

if command -v sha256sum >/dev/null 2>&1; then
  BASE_HASH="$(hash_input | sha256sum | cut -c1-16)"
else
  BASE_HASH="$(hash_input | shasum -a 256 | cut -c1-16)"
fi

BASE_TAG="base-${OPENCLAW_VERSION}-${BASE_HASH}"
BASE_IMAGE="${ACR_LOGIN_SERVER}/clawdbot-base:${BASE_TAG}"

# ---------------------------------------------------------------------------
# Build base image if it doesn't already exist in ACR.
# ---------------------------------------------------------------------------
base_exists=false
base_tag_count="$(az acr repository show-tags \
  --name "${ACR_NAME}" \
  --repository clawdbot-base \
  --query "[?@=='${BASE_TAG}'] | length(@)" \
  -o tsv 2>/dev/null || echo "0")"

if [ "${base_tag_count}" = "1" ]; then
  base_exists=true
fi

if [ "${base_exists}" != "true" ]; then
  echo "Building base image clawdbot-base:${BASE_TAG} in ACR '${ACR_NAME}'"
  az acr build \
    --registry "${ACR_NAME}" \
    --image "clawdbot-base:${BASE_TAG}" \
    --file "${BUILD_CONTEXT}/Dockerfile.base" \
    --build-arg "OPENCLAW_VERSION=${OPENCLAW_VERSION}" \
    "${BUILD_CONTEXT}"
else
  echo "Base image clawdbot-base:${BASE_TAG} already exists — skipping rebuild"
fi

# ---------------------------------------------------------------------------
# Build final (thin) image on top of the base.
# ---------------------------------------------------------------------------
echo "Building image 'clawdbot:${IMAGE_TAG}' in ACR '${ACR_NAME}'"
az acr build \
  --registry "${ACR_NAME}" \
  --image "clawdbot:${IMAGE_TAG}" \
  --file "${BUILD_CONTEXT}/Dockerfile" \
  --build-arg "BASE_IMAGE=${BASE_IMAGE}" \
  "${BUILD_CONTEXT}"

echo "Image build complete"
