# Advanced Deployment Guide

This guide covers design decisions, non-default options, and operational details.

## Architecture Summary

Resources deployed by `azd`:

- Azure Container Apps Environment
- Azure Container Registry
- Azure Storage Account with Azure File shares
- Azure Log Analytics Workspace
- Optional Azure Monitor scheduled-query alerts

Runtime layout:

- OpenClaw gateway runs in ACA
- `minReplicas=0` for scale-to-zero
- Cron scale rule wakes hourly from 8:00 AM to 8:00 PM Pacific
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

## GitOps and OIDC

Deployment workflow:

- `.github/workflows/deploy.yml`
- Trigger: push to `main`
- Auth: GitHub OIDC via `azure/login`
- Deploy command: `azd up --no-prompt`

OIDC setup instructions:

- [docs/github-oidc-setup.md](github-oidc-setup.md)

## Troubleshooting

### Gateway never becomes healthy

- Check logs:
  - `az containerapp logs show --name <app-name> --resource-group <rg> --follow`
- Verify `OPENCLAW_GATEWAY_TOKEN`, AOAI endpoint/key, and model deployment name.

### WhatsApp disconnected after restart

- Verify Azure Files mounts are attached
- Verify `/home/node/.openclaw` is persistent

### Voice notes not transcribed

- Verify `AZURE_SPEECH_KEY` and `AZURE_SPEECH_REGION`
- Confirm audio files are present in `/workspace/media`

### Outlook IMAP/SMTP failures

- Confirm app password (not account password)
- Confirm host/port values match Outlook defaults
