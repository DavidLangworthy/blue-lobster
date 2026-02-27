#!/bin/bash
# Print a tokenized OpenClaw Control UI URL for zero-click browser login.
set -euo pipefail

RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"
APP_NAME="${OPENCLAW_APP_NAME:-${CLAWDBOT_APP_NAME:-openclaw}}"
OPEN_BROWSER=false

usage() {
  cat <<'EOF'
Usage: scripts/dashboard-url.sh [options]

Options:
  -g, --resource-group <name>  Azure resource group (required if AZURE_RESOURCE_GROUP unset)
  -n, --app-name <name>        Container App name (default: openclaw)
      --open                   Open URL in browser (macOS: open, Linux: xdg-open)
  -h, --help                   Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--resource-group)
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    -n|--app-name|--name)
      APP_NAME="$2"
      shift 2
      ;;
    --open)
      OPEN_BROWSER=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${RESOURCE_GROUP}" ]]; then
  echo "ERROR: resource group is required (set AZURE_RESOURCE_GROUP or pass -g)." >&2
  exit 1
fi

FQDN="$(az containerapp show \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${APP_NAME}" \
  --query "properties.configuration.ingress.fqdn" \
  --output tsv)"

if [[ -z "${FQDN}" ]]; then
  echo "ERROR: failed to resolve FQDN for container app '${APP_NAME}' in '${RESOURCE_GROUP}'." >&2
  exit 1
fi

GATEWAY_TOKEN="$(az containerapp secret list \
  --resource-group "${RESOURCE_GROUP}" \
  --name "${APP_NAME}" \
  --show-values \
  --query "[?name=='gateway-token'].value | [0]" \
  --output tsv)"

if [[ -z "${GATEWAY_TOKEN}" || "${GATEWAY_TOKEN}" == "not-set" ]]; then
  echo "ERROR: gateway token is missing. Set OPENCLAW_GATEWAY_TOKEN and redeploy." >&2
  exit 1
fi

DASHBOARD_URL="https://${FQDN}/#token=${GATEWAY_TOKEN}"
echo "${DASHBOARD_URL}"

if [[ "${OPEN_BROWSER}" == "true" ]]; then
  if command -v open >/dev/null 2>&1; then
    open "${DASHBOARD_URL}"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "${DASHBOARD_URL}"
  else
    echo "WARNING: no browser opener found (open/xdg-open)." >&2
  fi
fi
