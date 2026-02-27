#!/bin/bash
# Azure OpenAI endpoint liveness probe for deployment-backed Responses API calls.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/aoai-liveness.sh [options]

Options:
  --endpoint <url>                   AOAI endpoint (or use AZURE_OPENAI_ENDPOINT)
  --api-key <key>                    AOAI API key (or use AZURE_OPENAI_API_KEY)
  --deployment <name>                AOAI deployment name (or use AZURE_OPENAI_DEPLOYMENT)
  --timeout <seconds>                HTTP timeout per probe (default: 20)
  --skip-encrypted-probe             Skip encrypted-content capability probe
  --require-encrypted-content        Fail if encrypted-content probe is unsupported
  -h, --help                         Show this help
EOF
}

ENDPOINT="${AZURE_OPENAI_ENDPOINT:-}"
API_KEY="${AZURE_OPENAI_API_KEY:-}"
DEPLOYMENT="${AZURE_OPENAI_DEPLOYMENT:-}"
TIMEOUT_SECONDS=20
RUN_ENCRYPTED_PROBE=true
REQUIRE_ENCRYPTED_CONTENT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --endpoint)
      ENDPOINT="${2:-}"
      shift 2
      ;;
    --api-key)
      API_KEY="${2:-}"
      shift 2
      ;;
    --deployment)
      DEPLOYMENT="${2:-}"
      shift 2
      ;;
    --timeout)
      TIMEOUT_SECONDS="${2:-20}"
      shift 2
      ;;
    --skip-encrypted-probe)
      RUN_ENCRYPTED_PROBE=false
      shift
      ;;
    --require-encrypted-content)
      REQUIRE_ENCRYPTED_CONTENT=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${ENDPOINT}" || -z "${API_KEY}" || -z "${DEPLOYMENT}" ]]; then
  echo "Missing required AOAI inputs. Need endpoint, api key, and deployment." >&2
  echo "Set AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_API_KEY, AZURE_OPENAI_DEPLOYMENT or pass flags." >&2
  exit 1
fi

ENDPOINT="${ENDPOINT%/}"

tmp_body="$(mktemp)"
tmp_probe="$(mktemp)"
cleanup() {
  rm -f "${tmp_body}" "${tmp_probe}"
}
trap cleanup EXIT

base_payload="$(cat <<EOF
{"model":"${DEPLOYMENT}","input":"healthcheck: reply with exactly ok","max_output_tokens":16}
EOF
)"

status="$(curl -sS -m "${TIMEOUT_SECONDS}" -o "${tmp_body}" -w "%{http_code}" \
  -X POST "${ENDPOINT}/openai/v1/responses" \
  -H "Content-Type: application/json" \
  -H "api-key: ${API_KEY}" \
  -d "${base_payload}")"

if [[ "${status}" -lt 200 || "${status}" -ge 300 ]]; then
  echo "AOAI base liveness failed (HTTP ${status})." >&2
  cat "${tmp_body}" >&2
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  reply_text="$(jq -r '.output[]?.content[]? | select(.type=="output_text") | .text' "${tmp_body}" | head -n1)"
else
  reply_text=""
fi

echo "AOAI base liveness: OK (deployment=${DEPLOYMENT}, reply=${reply_text:-n/a})"

if [[ "${RUN_ENCRYPTED_PROBE}" != "true" ]]; then
  exit 0
fi

encrypted_payload="$(cat <<EOF
{"model":"${DEPLOYMENT}","input":"healthcheck encrypted probe","include":["reasoning.encrypted_content"],"max_output_tokens":8}
EOF
)"

probe_status="$(curl -sS -m "${TIMEOUT_SECONDS}" -o "${tmp_probe}" -w "%{http_code}" \
  -X POST "${ENDPOINT}/openai/v1/responses" \
  -H "Content-Type: application/json" \
  -H "api-key: ${API_KEY}" \
  -d "${encrypted_payload}")"

if [[ "${probe_status}" -ge 200 && "${probe_status}" -lt 300 ]]; then
  echo "AOAI encrypted-content probe: supported"
  exit 0
fi

if grep -q "Encrypted content is not supported with this model" "${tmp_probe}"; then
  echo "AOAI encrypted-content probe: unsupported by this deployment/model."
  if [[ "${REQUIRE_ENCRYPTED_CONTENT}" == "true" ]]; then
    echo "Encrypted content support is required but unavailable." >&2
    exit 1
  fi
  exit 0
fi

echo "AOAI encrypted-content probe failed unexpectedly (HTTP ${probe_status})." >&2
cat "${tmp_probe}" >&2
exit 1
