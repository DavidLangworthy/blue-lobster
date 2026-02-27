# Advanced Deployment Guide

This guide covers design decisions, non-default options, and operational details.

## Architecture Summary

Resources deployed by `azd`:

- Azure Container Apps Environment
- Azure Container Registry (Basic SKU, or reused via `EXISTING_CONTAINER_REGISTRY_NAME`)
- Azure Storage Account with Azure File shares
- Azure Log Analytics Workspace
- Optional Azure Monitor scheduled-query alerts (disabled by default)

Runtime layout:

- OpenClaw gateway runs in ACA
- `minReplicas=0` for scale-to-zero
- Cron scale rule wakes hourly from 8:00 AM to 8:00 PM Pacific
- Idle scale cooldown is set to 3600 seconds, so a web hit keeps the app warm for about 1 hour
- Persistent mounts:
  - `/home/node/.openclaw` (sessions/tokens/config)
  - `/workspace` (prompt, ledgers, room state)
  - `/workspace/media` (voice media)

Wake semantics:

- Incoming WhatsApp or Outlook messages do not wake a zero-replica app by themselves in this configuration.
- The app wakes via ingress HTTP traffic (for example opening the web UI) or during configured cron windows.

## Model Strategy (Model-as-a-Service)

Primary model path:

- Azure OpenAI endpoint + key (pay-per-token)
- Deployment defaults to `gpt-5-2`
- OpenClaw provider is configured as an OpenAI-compatible endpoint with `openai-responses` API mode
- `AZURE_OPENAI_REASONING=false` by default to avoid unsupported `reasoning.encrypted_content` includes on non-reasoning deployments
- Bicep auto-provisions an Azure OpenAI account when endpoint/key are not supplied via secrets

This avoids dedicated PTU requirements and keeps cost usage-based.

## Voice Notes

Inbound voice note transcription order:

1. Azure Speech CLI adapter (`/app/azure-stt.sh`) when `AZURE_SPEECH_KEY` + `AZURE_SPEECH_REGION` are set
2. OpenAI fallback transcription model (`gpt-4o-mini-transcribe`)

Outbound TTS:

- Default provider: `edge`
- Premium option: set `ELEVENLABS_API_KEY` and `OPENCLAW_TTS_PROVIDER=elevenlabs`

## WhatsApp Integration Notes

This repo is configured for OpenClaw native WhatsApp Web channel login (QR pairing).

- No long-lived WhatsApp API token is required in this mode
- Session survives restarts because credentials are on Azure Files
- If you later move to Meta WhatsApp Cloud API, use a separate integration path

## Approval and Safety Posture

Configured defaults:

- WhatsApp channel enabled
- Browser tool enabled with Chromium (`/usr/bin/chromium`)
- Discord/Telegram channels blocked in config
- Exec approvals enabled for WhatsApp sessions (`/approve ...` workflow)

Recommended governance:

- Keep purchasing/payment actions behind explicit approvals
- Keep irreversible side effects logged in `SOURCING_LEDGER.csv`

## Memory Initialization

On first boot, `src/moltbot/init-workspace.sh` creates:

- `SYSTEM_PROMPT.md`
- `SOURCING_LEDGER.csv`
- `HEARTBEAT.md`
- Room canvas scaffolds under `/workspace/canvas/<room>/index.html`

## Network Exposure and Access

- ACA ingress is public by default
- Control UI auth is token-based (`OPENCLAW_GATEWAY_TOKEN`)
- Optional CIDR restrictions through `ALLOWED_IP_RANGES`
- Optional internal ingress via `INTERNAL_ONLY=true` (requires matching networking setup)
- Generate a one-click tokenized dashboard URL:
  - `./scripts/dashboard-url.sh -g <resource-group> -n openclaw`

## GitOps and OIDC

Deployment workflow:

- `.github/workflows/deploy.yml`
- Trigger: push to `main`
- Auth: GitHub OIDC via `azure/login`
- Deploy command: `azd up --no-prompt`

OIDC setup instructions:

- [docs/github-oidc-setup.md](github-oidc-setup.md)

## Cost Optimization Defaults

- `ENABLE_ALERTS=false` by default to avoid recurring alert-rule charges.
- `EXISTING_CONTAINER_REGISTRY_NAME` can be set to reuse one ACR across environments.
- If you keep per-environment registries, ACR remains on `Basic` SKU (lowest paid tier).

## E2E Validation (Web UX + WhatsApp)

Use this sequence to prove the full path is working end-to-end.

### 1. Health and tokenized dashboard

```bash
RG="rg-openclaw-prod"
APP="openclaw"

curl -sS "https://$(az containerapp show -g "$RG" -n "$APP" --query properties.configuration.ingress.fqdn -o tsv)/health"
./scripts/dashboard-url.sh -g "$RG" -n "$APP"
```

Open the printed URL and confirm the dashboard connects.

Optional AOAI deployment check:

```bash
./scripts/aoai-liveness.sh
```

### 2. Web UX -> LLM -> Web UX reply

1. In dashboard chat, send: `E2E-WEB: reply with exactly "web-ok"`.
2. Confirm assistant replies `web-ok`.
3. Verify logs show a successful run:

```bash
az containerapp logs show -g "$RG" -n "$APP" --tail 200 | rg -n "embedded run agent end|isError=false|All models failed|authentication_error"
```

Expected: `isError=false` and no auth errors.

### 3. WhatsApp pairing and message loop

1. In dashboard, go to Channels and start WhatsApp login to generate a fresh QR.
2. On phone: WhatsApp -> Linked devices -> Link a device -> scan QR.
3. Confirm channel state is linked/running in dashboard.
4. Send WhatsApp message: `E2E-WHATSAPP`.
5. Confirm agent replies in the same chat.
6. Verify logs:

```bash
az containerapp logs show -g "$RG" -n "$APP" --tail 300 | rg -n "whatsapp|received message|send|health-monitor"
```

### 4. Persistence check after restart

```bash
az containerapp revision restart -g "$RG" -n "$APP"
sleep 20
az containerapp logs show -g "$RG" -n "$APP" --tail 120 | rg -n "gateway listening|health-monitor started|whatsapp"
```

Expected: app returns healthy, and WhatsApp session reconnects without requiring a new QR.

## AOAI Auth Troubleshooting Matrix

| Symptom | Likely Cause | Fix |
|---|---|---|
| `No API key found for provider "openai"` | `AZURE_OPENAI_ENDPOINT` empty so config falls back to `openai/*` | Ensure `DEPLOY_AZURE_OPENAI=true` or set `AZURE_OPENAI_ENDPOINT` secret |
| `HTTP 401 authentication_error` from AOAI provider | Wrong AOAI key | Rotate key and update `AZURE_OPENAI_API_KEY` |
| `404 The API deployment for this resource does not exist` | `AZURE_OPENAI_DEPLOYMENT` does not match an AOAI deployment name | Create/update deployment and rerun `./scripts/aoai-liveness.sh` |
| `400 Encrypted content is not supported with this model` | Reasoning include sent to a deployment that does not support encrypted reasoning content | Keep `AZURE_OPENAI_REASONING=false` (default) or switch to a model/deployment that supports encrypted content |
| `HTTP 401 invalid x-api-key` for Anthropic | Optional fallback enabled without valid Anthropic key | Leave `OPENCLAW_MODEL_FALLBACKS` empty unless Anthropic is configured |
| Dashboard connected but no model replies | Gateway auth is fine, model provider auth is not | Check `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_API_KEY`, and deployment name |

## Troubleshooting

### Gateway never becomes healthy

- Check logs:
  - `az containerapp logs show --name <app-name> --resource-group <rg> --follow`
- Verify `OPENCLAW_GATEWAY_TOKEN` is set.
- For model auth, either:
  - let Bicep auto-create AOAI (`DEPLOY_AZURE_OPENAI=true`), or
  - set `AZURE_OPENAI_ENDPOINT` and `AZURE_OPENAI_API_KEY` secrets explicitly.

### Control UI says "gateway token missing"

- Use the helper to print a tokenized URL (includes `#token=...`):
  - `./scripts/dashboard-url.sh -g <resource-group> -n <app-name>`
- Open that URL once in each browser profile; the UI stores the token locally.

### Control UI says "disconnected from gateway" with `pairing required`

- Set `OPENCLAW_CONTROLUI_DISABLE_DEVICE_AUTH=true` (default in this repo).
- Redeploy so `gateway.controlUi.dangerouslyDisableDeviceAuth=true` is applied.
- If you intentionally require device pairing, set this to `false` and complete pairing in the UI.

### WhatsApp disconnected after restart

- Verify Azure Files mounts are attached
- Verify `/home/node/.openclaw` is persistent

### Voice notes not transcribed

- Verify `AZURE_SPEECH_KEY` and `AZURE_SPEECH_REGION`
- Confirm audio files are present in `/workspace/media`

### Outlook IMAP/SMTP failures

- Confirm app password (not account password)
- Confirm host/port values match Outlook defaults
