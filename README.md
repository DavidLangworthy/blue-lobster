# OpenClaw on Azure Container Apps (GitOps)

Deploy an autonomous OpenClaw agent to Azure Container Apps with:

- pay-per-token Azure OpenAI (`gpt-5.2`, Global Standard)
- scale-to-zero compute
- persistent Azure File Share memory/workspace
- WhatsApp channel (native OpenClaw WhatsApp Web)
- Outlook mailbox integration (IMAP/SMTP)
- GitHub Actions deployment via `azd` + OIDC

This repo is optimized for a simple happy path. Advanced options are documented separately.

## Happy Path (10-15 minutes)

## 1. Prerequisites

- Azure subscription with Contributor access
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI (`azd`)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- GitHub repo admin access (for Actions secrets)

## 2. Clone and login

```bash
git clone https://github.com/DavidLangworthy/blue-lobster.git
cd blue-lobster

azd auth login
az login
```

## 3. Create an `azd` environment

```bash
azd env new
```

Pick an environment name like `openclaw-prod`.

## 4. Set required secrets and settings

At minimum, set:

```bash
azd env set AZURE_LOCATION "eastus2"
azd env set AZURE_OPENAI_MODEL "gpt-5.2"
azd env set OPENCLAW_GATEWAY_TOKEN "<long-random-token>"
azd env set WHATSAPP_ALLOW_FROM "+15551234567"
```

For Outlook and WhatsApp credential setup, use:

- [docs/outlook-whatsapp-credentials.md](docs/outlook-whatsapp-credentials.md)

## 5. Provision and deploy

```bash
azd up
```

This provisions infrastructure and deploys the container app.

## 6. Pair WhatsApp

Once deployed, pair WhatsApp using the QR flow in OpenClaw channels login.

Credentials persist on Azure File Share and survive restarts/scale-to-zero.

## 7. Validate

- Health endpoint: `https://<app-fqdn>/health`
- Control UI: `https://<app-fqdn>/`
- Canvas rooms (example):
  - `https://<app-fqdn>/__openclaw__/canvas/living-room/`
  - `https://<app-fqdn>/__openclaw__/canvas/master-bedroom/`

## GitOps Deployment (main branch)

Use the workflow in `.github/workflows/deploy.yml`.

- Every push to `main` triggers deploy.
- Auth uses GitHub OIDC (no stored Azure service principal secret).

## Operational docs

- Advanced deployment and architecture: [docs/advanced-deployment.md](docs/advanced-deployment.md)
- Outlook + WhatsApp credentials: [docs/outlook-whatsapp-credentials.md](docs/outlook-whatsapp-credentials.md)

## Security defaults

- No OpenClaw API key required
- Gateway token auth enabled
- No secrets committed to git
- Side-effectful actions require approval flow (`/approve`)

## Cost model

This setup targets pay-per-use:

- Azure OpenAI Global Standard (pay-per-token)
- ACA `minReplicas=0` scale-to-zero
- Persistent storage only for agent state/workspace
