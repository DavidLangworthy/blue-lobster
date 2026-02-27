#!/bin/bash
# Post-provision hook: build and push the OpenClaw image.
set -euo pipefail

if [ "${SKIP_IMAGE_BUILD:-false}" = "true" ]; then
  echo "Post-provision: SKIP_IMAGE_BUILD=true; skipping application image build"
  exit 0
fi

echo "Post-provision: building application image"

if [ -z "${CONTAINER_REGISTRY_NAME:-}" ]; then
  echo "ERROR: CONTAINER_REGISTRY_NAME is not set" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/build-image.sh" "${CONTAINER_REGISTRY_NAME}" "latest" "${OPENCLAW_VERSION:-main}"

echo "Post-provision complete"
