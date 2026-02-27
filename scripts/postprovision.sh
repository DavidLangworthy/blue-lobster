#!/bin/bash
# Post-provision hook: build and push the OpenClaw image.
set -euo pipefail

echo "Post-provision: building application image"

if [ -z "${CONTAINER_REGISTRY_NAME:-}" ]; then
  echo "ERROR: CONTAINER_REGISTRY_NAME is not set" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/build-image.sh" "${CONTAINER_REGISTRY_NAME}" "latest" "${OPENCLAW_VERSION:-main}"

echo "Post-provision complete"
