# Outlook and WhatsApp Credentials

This deployment does not require an API key from OpenClaw itself.

You need credentials for the external services it connects to.

## Outlook (IMAP/SMTP mailbox auth)

Use an Outlook app password for mailbox access (recommended for simple IMAP/SMTP setup).

### Step 1: Enable two-step verification

1. Go to [https://account.microsoft.com/security](https://account.microsoft.com/security).
2. Open **Advanced security options**.
3. Turn on **Two-step verification**.

### Step 2: Create an app password

1. In **Advanced security options**, find **App passwords**.
2. Click **Create a new app password**.
3. Copy the generated password and store it as a secret.

### Step 3: Set deployment values

Set these values in your environment or secret store:

- `OUTLOOK_EMAIL`: your full Outlook address (for example `you@outlook.com`)
- `OUTLOOK_APP_PASSWORD`: app password from Step 2
- `IMAP_HOST`: `outlook.office365.com`
- `IMAP_PORT`: `993`
- `SMTP_HOST`: `smtp.office365.com`
- `SMTP_PORT`: `587`

## WhatsApp (OpenClaw native WhatsApp Web mode)

In native WhatsApp Web mode, there is no long-lived API token to create manually.

You pair the account once using QR login, then OpenClaw persists the session credentials.

### Step 1: Start gateway and trigger WhatsApp login

- Use the OpenClaw channel login flow (CLI or Control UI) to show a WhatsApp QR code.

### Step 2: Pair from phone

1. Open WhatsApp on your phone.
2. Go to **Linked devices**.
3. Tap **Link a device**.
4. Scan the QR code from Step 1.

### Step 3: Configure sender allowlist

Set your allowed WhatsApp sender(s):

- `WHATSAPP_ALLOW_FROM` (E.164 format, e.g. `+15551234567`)

### Persistence note

Store OpenClaw credentials on persistent storage (Azure File Share mount) so the WhatsApp session survives restarts and scale-to-zero.

## If you switch to Meta WhatsApp Cloud API later

That is a different integration path and does require Meta access tokens. This repo's native WhatsApp Web setup does not.
