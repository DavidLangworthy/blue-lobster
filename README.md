# OpenClaw on Azure Container Apps (GitOps)

Deploy an OpenClaw agent on Azure Container Apps with scale-to-zero, persistent Azure Files storage, WhatsApp, Outlook IMAP/SMTP, and GitHub Actions GitOps.

## Happy Path

### 1. Prerequisites

- Azure subscription with Contributor access
- Azure CLI
- Azure Developer CLI (`azd`)
- GitHub repo admin access
- `jq`
- Python 3 + `pip3`

### 2. Clone and sign in

```bash
git clone https://github.com/DavidLangworthy/blue-lobster.git
cd blue-lobster

az login
```

### 3. Run one-time GitHub OIDC + repo bootstrap (scripted)

```bash
chmod +x ./scripts/setup-gitops.sh
./scripts/setup-gitops.sh \
  --repo DavidLangworthy/blue-lobster \
  --install-tools
```

This script creates/updates:

- Entra app + service principal
- OIDC federated credential for `main`
- Azure role assignment for deploys
- GitHub Actions secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `OPENCLAW_GATEWAY_TOKEN`)
- GitHub Actions variables (location, env name, wake schedule, alerts off, etc.)

By default, infra now provisions an Azure OpenAI account and wires endpoint/key automatically in Bicep.
You only need `AZURE_OPENAI_ENDPOINT` and `AZURE_OPENAI_API_KEY` secrets if you want to override with an existing account.

### 4. Set channel + mailbox secrets (optional now, needed for full behavior)

```bash
gh secret set WHATSAPP_ALLOW_FROM -R DavidLangworthy/blue-lobster
gh secret set OUTLOOK_EMAIL -R DavidLangworthy/blue-lobster
gh secret set OUTLOOK_APP_PASSWORD -R DavidLangworthy/blue-lobster
```

Credential walkthroughs:

- [docs/outlook-whatsapp-credentials.md](docs/outlook-whatsapp-credentials.md)

### 5. Deploy

```bash
git push origin main
```

GitHub Actions provisions infra, builds the container image in ACR, and deploys to ACA.

### 6. Pair WhatsApp and test

- Print a tokenized dashboard URL (auto-fills gateway token in the UI):

```bash
./scripts/dashboard-url.sh -g <resource-group> -n openclaw
```

- Open the printed URL
- Start WhatsApp channel login (QR flow)
- Send a test message and a voice note
- Validate AOAI endpoint/deployment liveness:

```bash
./scripts/aoai-liveness.sh
```

## What this deploy includes

- Azure Container Apps with `minReplicas=0` (scale-to-zero)
- Cron wake window hourly from 8:00 AM to 8:00 PM Pacific
- Web/API traffic keeps the app warm for ~1 hour after the last request (`SCALE_COOLDOWN_SECONDS=3600`)
- Persistent Azure File shares mounted at:
  - `/home/node/.openclaw`
  - `/workspace`
  - `/workspace/media`
- Azure OpenAI model-as-a-service wiring (`openai-responses` API style)
- AOAI reasoning include disabled by default (`AZURE_OPENAI_REASONING=false`) for broad model compatibility
- AOAI liveness probe script: `./scripts/aoai-liveness.sh`
- Optional Azure Speech STT (`src/moltbot/azure-stt.sh`)
- Optional ElevenLabs TTS via `ELEVENLABS_API_KEY`
- Live Canvas over ingress with room paths like:
  - `/__openclaw__/canvas/living-room/`
  - `/__openclaw__/canvas/master-bedroom/`
- Azure Monitor alerts default to off (`ENABLE_ALERTS=false`) to minimize idle cost

## GitOps

Pushes to `main` auto-deploy via:

- [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml)

One-time OIDC setup guide:

- [docs/github-oidc-setup.md](docs/github-oidc-setup.md)

GitOps bootstrap script:

- [scripts/setup-gitops.sh](scripts/setup-gitops.sh)

## Docs

- Advanced architecture and operations: [docs/advanced-deployment.md](docs/advanced-deployment.md)
- Outlook and WhatsApp credentials: [docs/outlook-whatsapp-credentials.md](docs/outlook-whatsapp-credentials.md)
- GitHub OIDC setup: [docs/github-oidc-setup.md](docs/github-oidc-setup.md)
- E2E validation flow: [docs/advanced-deployment.md#e2e-validation-web-ux--whatsapp](docs/advanced-deployment.md#e2e-validation-web-ux--whatsapp)

## Cost Notes

- ACR is already configured with `Basic` SKU (lowest paid tier).
- For multiple environments, set `EXISTING_CONTAINER_REGISTRY_NAME` to reuse one registry and avoid paying for extra ACR instances.
- Keep `ENABLE_ALERTS=false` unless you actively need alert rules.
