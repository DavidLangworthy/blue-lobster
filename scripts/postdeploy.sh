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

AOAI_ENDPOINT="${AZURE_OPENAI_ENDPOINT:-}"
AOAI_KEY="${AZURE_OPENAI_API_KEY:-}"
AOAI_DEPLOYMENT="${AZURE_OPENAI_DEPLOYMENT:-}"
AOAI_ACCOUNT_NAME="${AZURE_OPENAI_ACCOUNT_NAME:-}"
AOAI_LIVENESS="skipped"

if [ -z "${AOAI_KEY}" ] && [ -n "${AOAI_ACCOUNT_NAME}" ] && [ -n "${RESOURCE_GROUP}" ] && command -v az >/dev/null 2>&1; then
  AOAI_KEY="$(az cognitiveservices account keys list -g "${RESOURCE_GROUP}" -n "${AOAI_ACCOUNT_NAME}" --query key1 -o tsv 2>/dev/null || true)"
fi

if [ -n "${AOAI_ENDPOINT}" ] && [ -n "${AOAI_KEY}" ] && [ -n "${AOAI_DEPLOYMENT}" ]; then
  if ./scripts/aoai-liveness.sh --endpoint "${AOAI_ENDPOINT}" --api-key "${AOAI_KEY}" --deployment "${AOAI_DEPLOYMENT}"; then
    AOAI_LIVENESS="ok"
  else
    AOAI_LIVENESS="failed"
  fi
fi

echo "AOAI liveness: ${AOAI_LIVENESS}"
echo
echo "Next steps"
if [ -n "${RESOURCE_GROUP}" ] && [ -n "${APP_NAME}" ]; then
  echo "1. Print tokenized dashboard URL: ./scripts/dashboard-url.sh -g ${RESOURCE_GROUP} -n ${APP_NAME}"
else
  echo "1. Open the control UI with your gateway token."
fi
echo "2. Pair WhatsApp in Channels login (QR flow)."
echo "3. Test a voice note and verify transcription."
if [ -n "${RESOURCE_GROUP}" ] && [ -n "${APP_NAME}" ]; then
  echo "4. Tail logs if needed: az containerapp logs show --name ${APP_NAME} --resource-group ${RESOURCE_GROUP} --follow"
fi
