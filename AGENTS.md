# AGENTS

## Mission
This repo deploys OpenClaw on Azure Container Apps via GitOps. Prefer deterministic, scripted changes over manual portal changes.

## Non-negotiable Rules
- Always validate both paths before calling a change done:
  - Web UX -> gateway -> model reply
  - WhatsApp inbound -> gateway -> model reply (when paired)
- Never rely on `:latest` image tags.
- Keep OpenClaw runtime version pinned (`OPENCLAW_VERSION`) unless intentionally upgraded.
- Any manual hotfix in Azure must be mirrored back into repo config before closing work.

## Required Checks Before Reporting Success
1. `az containerapp show -g rg-openclaw-prod -n openclaw --query "properties.latestRevisionName" -o tsv`
2. `az containerapp logs show -g rg-openclaw-prod -n openclaw --tail 200 --format text`
3. AOAI liveness:
   - `./scripts/aoai-liveness.sh --endpoint <endpoint> --api-key <key> --deployment <deployment>`
4. Web UX smoke test:
   - Open dashboard URL and send `heartbeat`
   - Confirm no 401/404 model errors in logs
5. WhatsApp channel status:
   - Verify paired/connected status or explicit pairing-required state

## Build/Deploy Behavior
- Workflow computes image tag from `src/moltbot` tree hash.
- Docs-only commits should reuse existing image tag and skip image rebuild.
- Rebuild image only when `src/moltbot` changes or `IMAGE_TAG_OVERRIDE` is set.

## Troubleshooting Notes
- Azure OpenAI in this repo uses provider `azure-openai-responses`.
- Model compatibility sets `supportsStore: false` for Azure Responses.
- If chat fails with auth errors, inspect runtime env + provider config first; do not assume key mismatch.
