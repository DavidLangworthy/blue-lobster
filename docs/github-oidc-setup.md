# GitHub OIDC Setup for `deploy.yml`

This is a one-time setup so GitHub Actions can deploy with `azd` using federated identity.

## 1. Create an Entra app registration

```bash
az ad app create --display-name "blue-lobster-github-oidc"
```

Capture the app ID (`appId`), then create a service principal:

```bash
APP_ID="<app-id>"
az ad sp create --id "$APP_ID"
```

## 2. Add federated credential for GitHub Actions

Create `federated-credential.json`:

```json
{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:DavidLangworthy/blue-lobster:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}
```

Apply it:

```bash
az ad app federated-credential create --id "$APP_ID" --parameters @federated-credential.json
```

## 3. Grant Azure RBAC to the service principal

Assign at subscription scope (Contributor is simplest to start):

```bash
SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
SP_OBJECT_ID="$(az ad sp show --id "$APP_ID" --query id -o tsv)"

az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role Contributor \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

For tighter security, use resource-group scope and least-privilege custom roles.

## 4. Add GitHub secrets

Repository `Settings -> Secrets and variables -> Actions`:

Required secrets:

- `AZURE_CLIENT_ID` (the app ID)
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `OPENCLAW_GATEWAY_TOKEN`
- `AZURE_OPENAI_ENDPOINT`
- `AZURE_OPENAI_API_KEY`

Common optional secrets:

- `WHATSAPP_ALLOW_FROM`
- `OUTLOOK_EMAIL`
- `OUTLOOK_APP_PASSWORD`
- `AZURE_SPEECH_KEY`
- `AZURE_SPEECH_REGION`
- `ELEVENLABS_API_KEY`
- `ANTHROPIC_API_KEY`

Recommended repository variables:

- `AZD_ENV_NAME` (example: `openclaw-prod`)
- `AZURE_LOCATION` (example: `eastus2`)
- `AZURE_OPENAI_DEPLOYMENT` (example: `gpt-5-2`)
- `OPENCLAW_ROOMS` (example: `living-room,master-bedroom`)

## 5. Validate workflow

Push to `main` and check `.github/workflows/deploy.yml` run output.

The workflow will:

1. OIDC-login to Azure
2. Select/create the `azd` environment
3. Apply env settings
4. Run `azd up --no-prompt`
