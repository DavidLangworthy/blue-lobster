# OpenClaw on Azure Container Apps (GitOps)

Deploy an OpenClaw agent on Azure Container Apps with scale-to-zero, persistent Azure Files storage, WhatsApp, Outlook IMAP/SMTP, and GitHub Actions GitOps.

## Happy Path

### 1. Prerequisites

- Azure subscription with Contributor access
- Azure CLI
- Azure Developer CLI (`azd`)
- GitHub repo admin access

### 2. Clone and sign in

```bash
git clone https://github.com/DavidLangworthy/blue-lobster.git
cd blue-lobster

az login
azd auth login
```

### 3. Create an `azd` environment

```bash
azd env new
```

Pick a name like `openclaw-prod`.

### 4. Set required values

```bash
azd env set AZURE_LOCATION "eastus2"
azd env set OPENCLAW_GATEWAY_TOKEN "<long-random-token>"
azd env set AZURE_OPENAI_ENDPOINT "https://<your-aoai>.openai.azure.com"
azd env set AZURE_OPENAI_API_KEY "<aoai-key>"
azd env set AZURE_OPENAI_DEPLOYMENT "gpt-5-2"
```

### 5. Set channel + mailbox values

```bash
azd env set WHATSAPP_ALLOW_FROM "+15551234567"
azd env set OUTLOOK_EMAIL "you@outlook.com"
azd env set OUTLOOK_APP_PASSWORD "<outlook-app-password>"
```

Credential walkthroughs:

- [docs/outlook-whatsapp-credentials.md](docs/outlook-whatsapp-credentials.md)

### 6. Deploy

```bash
azd up
```

This provisions infra, builds the container image in ACR, and deploys to ACA.

### 7. Pair WhatsApp and test

- Open `https://<app-fqdn>/` and authenticate using `OPENCLAW_GATEWAY_TOKEN`
- Start WhatsApp channel login (QR flow)
- Send a test message and a voice note

## What this deploy includes

- Azure Container Apps with `minReplicas=0` (scale-to-zero)
- Cron wake window hourly from 8:00 AM to 8:00 PM Pacific
- Persistent Azure File shares mounted at:
  - `/home/node/.openclaw`
  - `/workspace`
  - `/workspace/media`
- Azure OpenAI model-as-a-service wiring (`openai-responses` API style)
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

## Docs

- Advanced architecture and operations: [docs/advanced-deployment.md](docs/advanced-deployment.md)
- Outlook and WhatsApp credentials: [docs/outlook-whatsapp-credentials.md](docs/outlook-whatsapp-credentials.md)
- GitHub OIDC setup: [docs/github-oidc-setup.md](docs/github-oidc-setup.md)

## Cost Notes

- ACR is already configured with `Basic` SKU (lowest paid tier).
- For multiple environments, set `EXISTING_CONTAINER_REGISTRY_NAME` to reuse one registry and avoid paying for extra ACR instances.
- Keep `ENABLE_ALERTS=false` unless you actively need alert rules.
