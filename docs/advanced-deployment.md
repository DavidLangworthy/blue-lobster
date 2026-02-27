# Advanced Deployment Guide

This document contains deeper operational and architecture details.

If you are new to this repo, start with [README.md](../README.md).

## Architecture

Core resources:

- Azure Container Apps Environment
- Azure Container Registry
- Azure Storage Account + Azure File Share mounts
- Azure Log Analytics
- Azure OpenAI (Global Standard deployment)

Runtime behavior:

- OpenClaw gateway runs in ACA
- scale-to-zero enabled (`minReplicas=0`)
- periodic wake/check handled by scheduler configuration
- persistent state mounted from Azure File Share

## Model Strategy

Default:

- `openai/gpt-5.2` via Azure OpenAI Global Standard

Why this mode:

- pay-per-token billing
- no dedicated PTU requirement
- stable Azure OpenAI deployment pattern

## Channels and Integrations

Primary channel:

- WhatsApp Web (native OpenClaw channel)

Mail integration:

- Outlook mailbox over IMAP/SMTP

Voice notes:

- inbound transcription: OpenClaw media audio pipeline
- outbound audio: OpenClaw TTS pipeline

## Approval Gates

Web browsing can run autonomously.

Email sends and purchase-like actions are approval-gated and resolved via:

- `/approve <id> allow-once`
- `/approve <id> deny`

## Persistence

Persisted paths should include:

- OpenClaw credentials directory
- workspace markdown/csv files
- canvas artifacts

This ensures continuity across scale-down and restarts.

## GitHub Actions and OIDC

Deployment workflow:

- trigger on push to `main`
- login with `azure/login` using OIDC
- run `azd up`/`azd deploy`

No static Azure client secret should be stored in GitHub.

## Forkability Guidelines

To keep this template reusable:

- parameterize all account-specific values
- avoid hardcoded subscription/resource IDs
- never commit secrets
- keep docs explicit about required environment variables

## Troubleshooting

### WhatsApp not connected

- Re-run channel login QR flow.
- Verify credential mount is persistent.

### No replies after scale-up

- Check ACA logs.
- Verify model credentials and gateway token.

### Outlook auth failures

- Confirm app password is in use.
- Confirm IMAP/SMTP host+port values.

### Deployment failures for AOAI model

- Region/model availability can vary.
- Retry with supported region/model override.
