#!/bin/bash
# Post-deploy verification for OpenClaw on Azure Container Apps.
set -euo pipefail

APP_NAME="${OPENCLAW_APP_NAME:-${CLAWDBOT_APP_NAME:-openclaw}}"
GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-${CLAWDBOT_GATEWAY_URL:-}}"
RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-}"

if [ -z "${GATEWAY_URL}" ]; then
  echo "ERROR: OPENCLAW_GATEWAY_URL (or CLAWDBOT_GATEWAY_URL) is not set" >&2
  exit 1
fi

echo "Post-deploy verification"
echo "Checking gateway health at ${GATEWAY_URL}/health"

MAX_RETRIES=30
RETRY_COUNT=0
IS_HEALTHY=false

while [ "${RETRY_COUNT}" -lt "${MAX_RETRIES}" ] && [ "${IS_HEALTHY}" = "false" ]; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  HTTP_CODE="$(curl -s -o /dev/null -w "%{http_code}" "${GATEWAY_URL}/health" 2>/dev/null || echo "000")"
  if [ "${HTTP_CODE}" = "200" ]; then
    IS_HEALTHY=true
  else
    echo "  attempt ${RETRY_COUNT}/${MAX_RETRIES} - waiting for gateway"
    sleep 10
  fi
done

if [ "${IS_HEALTHY}" != "true" ]; then
  echo "WARNING: health check timed out"
  if [ -n "${RESOURCE_GROUP}" ] && [ -n "${APP_NAME}" ]; then
    echo "Inspect logs: az containerapp logs show --name ${APP_NAME} --resource-group ${RESOURCE_GROUP} --follow"
  fi
fi

echo
echo "Deployment status summary"
echo "Gateway URL: ${GATEWAY_URL}"
echo "Health: ${IS_HEALTHY}"
echo
echo "Next steps"
echo "1. Open the control UI with your gateway token."
echo "2. Pair WhatsApp in Channels login (QR flow)."
echo "3. Test a voice note and verify transcription."
if [ -n "${RESOURCE_GROUP}" ] && [ -n "${APP_NAME}" ]; then
  echo "4. Tail logs if needed: az containerapp logs show --name ${APP_NAME} --resource-group ${RESOURCE_GROUP} --follow"
fi
