#!/usr/bin/env bash
# One-time GitOps bootstrap for GitHub Actions OIDC + repo secrets/variables.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/setup-gitops.sh [options]

Options:
  --repo <owner/repo>               GitHub repo (default: inferred from origin remote)
  --branch <name>                   Git branch for OIDC subject (default: main)
  --app-name <name>                 Entra app display name (default: blue-lobster-github-oidc)
  --role <role>                     Primary Azure role for workflow identity (default: Contributor)
  --scope <azure-scope>             Role assignment scope (default: subscription)
  --azd-env-name <name>             GitHub variable AZD_ENV_NAME (default: openclaw-prod)
  --azure-location <location>       GitHub variable AZURE_LOCATION (default: eastus2)
  --existing-acr-name <name>        Optional shared ACR name (sets EXISTING_CONTAINER_REGISTRY_NAME variable)
  --openclaw-gateway-token <token>  OPENCLAW_GATEWAY_TOKEN secret (default: generated)
  --aoai-endpoint <url>             Optional AZURE_OPENAI_ENDPOINT secret
  --aoai-key <key>                  Optional AZURE_OPENAI_API_KEY secret
  --dry-run                         Print planned actions without applying
  -h, --help                        Show help

Examples:
  ./scripts/setup-gitops.sh
  ./scripts/setup-gitops.sh --repo DavidLangworthy/blue-lobster --aoai-endpoint "https://my-aoai.openai.azure.com" --aoai-key "<key>"
USAGE
}

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: required command not found: ${cmd}" >&2
    exit 1
  fi
}

infer_repo_from_origin() {
  local origin
  origin="$(git config --get remote.origin.url || true)"
  if [[ -z "${origin}" ]]; then
    return 1
  fi

  if [[ "${origin}" =~ ^https://github\.com/([^/]+)/([^/.]+)(\.git)?$ ]]; then
    printf '%s/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi

  if [[ "${origin}" =~ ^git@github\.com:([^/]+)/([^/.]+)(\.git)?$ ]]; then
    printf '%s/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi

  return 1
}

run_cmd() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '+ %q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

set_gh_secret() {
  local repo="$1"
  local name="$2"
  local value="$3"
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "+ gh secret set ${name} -R ${repo} (value hidden)"
  else
    printf '%s' "${value}" | gh secret set "${name}" -R "${repo}" >/dev/null
  fi
}

set_gh_variable() {
  local repo="$1"
  local name="$2"
  local value="$3"
  run_cmd gh variable set "${name}" -R "${repo}" --body "${value}" >/dev/null
}

REPO=""
BRANCH="main"
APP_NAME="blue-lobster-github-oidc"
ROLE="Contributor"
RBAC_ADMIN_ROLE="User Access Administrator"
SCOPE=""
AZD_ENV_NAME="openclaw-prod"
AZURE_LOCATION="eastus2"
EXISTING_ACR_NAME=""
OPENCLAW_GATEWAY_TOKEN=""
AOAI_ENDPOINT=""
AOAI_KEY=""
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --app-name) APP_NAME="$2"; shift 2 ;;
    --role) ROLE="$2"; shift 2 ;;
    --scope) SCOPE="$2"; shift 2 ;;
    --azd-env-name) AZD_ENV_NAME="$2"; shift 2 ;;
    --azure-location) AZURE_LOCATION="$2"; shift 2 ;;
    --existing-acr-name) EXISTING_ACR_NAME="$2"; shift 2 ;;
    --openclaw-gateway-token) OPENCLAW_GATEWAY_TOKEN="$2"; shift 2 ;;
    --aoai-endpoint) AOAI_ENDPOINT="$2"; shift 2 ;;
    --aoai-key) AOAI_KEY="$2"; shift 2 ;;
    --dry-run) DRY_RUN="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd az
require_cmd gh
require_cmd openssl
require_cmd git

if [[ -z "${REPO}" ]]; then
  REPO="$(infer_repo_from_origin || true)"
fi

if [[ -z "${REPO}" ]]; then
  echo "ERROR: could not infer repository. Pass --repo <owner/repo>." >&2
  exit 1
fi

if [[ "${DRY_RUN}" != "true" ]]; then
  az account show >/dev/null
  gh auth status >/dev/null
fi

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"

if [[ -z "${SCOPE}" ]]; then
  SCOPE="/subscriptions/${SUBSCRIPTION_ID}"
fi

echo "Bootstrapping GitOps for ${REPO}"
echo "Azure subscription: ${SUBSCRIPTION_ID}"
echo "Azure scope: ${SCOPE}"

APP_ID="$(az ad app list --display-name "${APP_NAME}" --query "[0].appId" -o tsv)"
APP_OBJECT_ID="$(az ad app list --display-name "${APP_NAME}" --query "[0].id" -o tsv)"

if [[ -z "${APP_ID}" || -z "${APP_OBJECT_ID}" ]]; then
  echo "Creating Entra app registration: ${APP_NAME}"
  read -r APP_ID APP_OBJECT_ID < <(
    az ad app create \
      --display-name "${APP_NAME}" \
      --query "[appId,id]" \
      -o tsv
  )
else
  echo "Using existing Entra app registration: ${APP_NAME} (${APP_ID})"
fi

SP_OBJECT_ID="$(az ad sp show --id "${APP_ID}" --query id -o tsv 2>/dev/null || true)"
if [[ -z "${SP_OBJECT_ID}" ]]; then
  echo "Creating service principal for app ${APP_ID}"
  SP_OBJECT_ID="$(az ad sp create --id "${APP_ID}" --query id -o tsv)"
else
  echo "Using existing service principal: ${SP_OBJECT_ID}"
fi

FED_NAME="github-${BRANCH}"
FED_SUBJECT="repo:${REPO}:ref:refs/heads/${BRANCH}"
FED_FILE="/tmp/${APP_NAME//[^a-zA-Z0-9_-]/_}-federated.json"

cat > "${FED_FILE}" <<JSON
{
  "name": "${FED_NAME}",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "${FED_SUBJECT}",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}
JSON

FED_ID="$(az ad app federated-credential list --id "${APP_OBJECT_ID}" --query "[?name=='${FED_NAME}'].id | [0]" -o tsv)"
if [[ -n "${FED_ID}" ]]; then
  echo "Updating federated credential: ${FED_NAME}"
  run_cmd az ad app federated-credential update --id "${APP_OBJECT_ID}" --federated-credential-id "${FED_ID}" --parameters "@${FED_FILE}" >/dev/null
else
  echo "Creating federated credential: ${FED_NAME}"
  run_cmd az ad app federated-credential create --id "${APP_OBJECT_ID}" --parameters "@${FED_FILE}" >/dev/null
fi

ensure_role_assignment() {
  local role_name="$1"
  local assignment_id

  assignment_id="$(
    az role assignment list \
      --assignee-object-id "${SP_OBJECT_ID}" \
      --scope "${SCOPE}" \
      --role "${role_name}" \
      --query "[0].id" \
      -o tsv
  )"

  if [[ -z "${assignment_id}" ]]; then
    echo "Creating role assignment: ${role_name}"
    run_cmd az role assignment create \
      --assignee-object-id "${SP_OBJECT_ID}" \
      --assignee-principal-type ServicePrincipal \
      --role "${role_name}" \
      --scope "${SCOPE}" >/dev/null
  else
    echo "Role assignment already exists for '${role_name}': ${assignment_id}"
  fi
}

ensure_role_assignment "${ROLE}"
ensure_role_assignment "${RBAC_ADMIN_ROLE}"

if [[ -z "${OPENCLAW_GATEWAY_TOKEN}" ]]; then
  OPENCLAW_GATEWAY_TOKEN="$(openssl rand -hex 24)"
fi

echo "Setting GitHub Actions secrets"
set_gh_secret "${REPO}" "AZURE_CLIENT_ID" "${APP_ID}"
set_gh_secret "${REPO}" "AZURE_TENANT_ID" "${TENANT_ID}"
set_gh_secret "${REPO}" "AZURE_SUBSCRIPTION_ID" "${SUBSCRIPTION_ID}"
set_gh_secret "${REPO}" "OPENCLAW_GATEWAY_TOKEN" "${OPENCLAW_GATEWAY_TOKEN}"

if [[ -n "${AOAI_ENDPOINT}" ]]; then
  set_gh_secret "${REPO}" "AZURE_OPENAI_ENDPOINT" "${AOAI_ENDPOINT}"
fi

if [[ -n "${AOAI_KEY}" ]]; then
  set_gh_secret "${REPO}" "AZURE_OPENAI_API_KEY" "${AOAI_KEY}"
fi

echo "Setting GitHub Actions variables"
set_gh_variable "${REPO}" "AZD_ENV_NAME" "${AZD_ENV_NAME}"
set_gh_variable "${REPO}" "AZURE_LOCATION" "${AZURE_LOCATION}"
set_gh_variable "${REPO}" "ENABLE_ALERTS" "false"
set_gh_variable "${REPO}" "INTERNAL_ONLY" "false"
set_gh_variable "${REPO}" "OPENCLAW_MODEL_FALLBACKS" "anthropic/claude-sonnet-4-6"
set_gh_variable "${REPO}" "OPENCLAW_ROOMS" "living-room,master-bedroom"
set_gh_variable "${REPO}" "OPENCLAW_TTS_PROVIDER" "edge"
set_gh_variable "${REPO}" "OPENCLAW_TTS_AUTO" "inbound"
set_gh_variable "${REPO}" "AZURE_OPENAI_DEPLOYMENT" "gpt-5-2"
set_gh_variable "${REPO}" "SCALE_POLLING_INTERVAL_SECONDS" "30"
set_gh_variable "${REPO}" "SCALE_COOLDOWN_SECONDS" "3600"
set_gh_variable "${REPO}" "HEARTBEAT_CRON_START" "0 8-20 * * *"
set_gh_variable "${REPO}" "HEARTBEAT_CRON_END" "5 8-20 * * *"
set_gh_variable "${REPO}" "HEARTBEAT_CRON_TIMEZONE" "America/Los_Angeles"

if [[ -n "${EXISTING_ACR_NAME}" ]]; then
  set_gh_variable "${REPO}" "EXISTING_CONTAINER_REGISTRY_NAME" "${EXISTING_ACR_NAME}"
fi

echo
echo "Bootstrap complete."
echo "Repo: ${REPO}"
echo "App ID: ${APP_ID}"
echo "Service Principal: ${SP_OBJECT_ID}"
echo "Gateway token secret: OPENCLAW_GATEWAY_TOKEN (set)"
if [[ -z "${AOAI_ENDPOINT}" || -z "${AOAI_KEY}" ]]; then
  echo "Note: AZURE_OPENAI_ENDPOINT and/or AZURE_OPENAI_API_KEY were not provided."
  echo "      Set them via script flags or GH secrets before expecting model responses."
fi
